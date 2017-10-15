//
//  RxDataFlowController.swift
//  RxState
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

public protocol RxDataFlowControllerType {
	func dispatch(_ action: RxActionType)
}

public protocol RxStateType { }

public typealias RxStateMutator<State: RxStateType> = (State) -> (State)

public typealias RxReducer<State: RxStateType> = (RxActionType, State) -> Observable<RxStateMutator<State>>

public protocol RxActionType {
	var scheduler: ImmediateSchedulerType? { get }
	var isSerial: Bool { get }
}

public struct RxCompositeAction : RxActionType {
	public let scheduler: ImmediateSchedulerType?
	public let actions: [RxActionType]
	public let isSerial: Bool
	public let fallbackAction: RxActionType?
	
	public init(actions: [RxActionType], fallbackAction: RxActionType? = nil, isSerial: Bool = true, scheduler: ImmediateSchedulerType? = nil) {
		self.actions = actions
		self.fallbackAction = fallbackAction
		self.isSerial = isSerial
		self.scheduler = scheduler
	}
	
	public init(_ actions: RxActionType..., fallbackAction: RxActionType? = nil, isSerial: Bool = true, scheduler: ImmediateSchedulerType? = nil) {
		self.actions = actions
		self.fallbackAction = fallbackAction
		self.isSerial = isSerial
		self.scheduler = scheduler
	}
}

public struct RxInitializationAction : RxActionType {
	public let isSerial = true
	public var scheduler: ImmediateSchedulerType?
}

fileprivate enum FlowControllerError: Error {
	case compositeActionError(erroredAction: RxActionType, error: Error)
}


public class RxDataFlowController<State: RxStateType> : RxDataFlowControllerType {
	public var state: Observable<(setBy: RxActionType, state: State)> { return currentStateSubject.asObservable().observeOn(scheduler) }
	public var currentState: (setBy: RxActionType, state: State) { return try! currentStateSubject.value() }
	public var errors: Observable<(state: State, action: RxActionType, error: Error)> { return errorsSubject }
	
	let bag = DisposeBag()
	let reducer: RxReducer<State>
	let scheduler: ImmediateSchedulerType
	
	let actionsSubject: PublishSubject<RxActionType> = PublishSubject()
	
	let currentStateSubject: BehaviorSubject<(setBy: RxActionType, state: State)>
	let errorsSubject = PublishSubject<(state: State, action: RxActionType, error: Error)>()
	
	public convenience init(reducer: @escaping RxReducer<State>,
	                        initialState: State,
	                        dispatchAction: RxActionType? = nil) {
		self.init(reducer: reducer,
		          initialState: initialState,
		          scheduler: SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "com.RxDataFlowController.Scheduler"),
		          dispatchAction: dispatchAction)
	}
	
	init(reducer: @escaping RxReducer<State>,
	     initialState: State,
	     scheduler: ImmediateSchedulerType,
	     dispatchAction: RxActionType? = nil) {
		self.scheduler = scheduler
		self.reducer = reducer
		
		currentStateSubject = BehaviorSubject(value: (setBy: RxInitializationAction(), state: initialState))

		actionsSubject
			.map { [weak self] action -> Observable<Void> in return self?.observe(action: action) ?? .empty() }
			.merge(maxConcurrent: 1)
			.subscribe()
			.disposed(by: bag)
		
		if let dispatchAction = dispatchAction {
			dispatch(dispatchAction)
		}
	}
	
	private func propagate(error: Error, from action: RxActionType) {
		if case FlowControllerError.compositeActionError(let data) = error {
			errorsSubject.onNext((state: currentState.state, action: data.erroredAction, error: data.error))
		} else {
			errorsSubject.onNext((state: currentState.state, action: action, error: error))
		}
	}
	
	private func scheduler(for action: RxActionType, owner: RxCompositeAction? = nil) -> ImmediateSchedulerType {
		let actionScheduler =  action.scheduler ?? owner?.scheduler
		return actionScheduler ?? scheduler
	}
	
	private func descriptor(for action: RxActionType, owner: RxCompositeAction? = nil) -> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> {
		let schedulerForAction = scheduler(for: action, owner: owner)
		return Observable<RxActionType>.from([action], scheduler: schedulerForAction)
			.flatMap { [weak self] act in return self == nil ? .empty() : self!.reducer(act, self!.currentState.state).subscribeOn(schedulerForAction) }
			.observeOn(schedulerForAction)
			.flatMap { result -> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> in return .just((setBy: action, mutator: result)) }
	}
	
	private func mutateState(with mutator: RxStateMutator<State>) -> State {
		return mutator(currentState.state)
	}
	
	private func schedule(actionDescriptor: Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)>, for action: RxActionType)
		-> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> {
			guard !action.isSerial else { return actionDescriptor.observeOn(scheduler) }
			
			return Observable.create { [weak self] observer in
				guard let object = self else { return Disposables.create() }
				actionDescriptor
					.observeOn(object.scheduler)
					.do(onNext: { [weak self] next in
						guard let newState = self?.mutateState(with: next.mutator) else { return }
						self?.currentStateSubject.onNext((setBy: next.setBy, state: newState))
						},
					    onError: { [weak self] in self?.propagate(error: $0, from: action) })
					.subscribeOn(action.scheduler ?? object.scheduler)
					.subscribe()
					.disposed(by: object.bag)

				observer.onCompleted()

				return Disposables.create()
			}
	}
	
	private func observe(action: RxActionType) -> Observable<Void> {
		let descriptor: Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> = { [weak self] in
			guard let object = self else { return .empty() }
			
			guard let compositeAction = action as? RxCompositeAction else {
				return object.descriptor(for: action)
			}
			
			return object.observe(compositeAction: compositeAction)
		}()
		
		return schedule(actionDescriptor: descriptor, for: action)
			.observeOn(scheduler)
			.do(onNext: { [weak self] next in
				guard let newState = self?.mutateState(with: next.mutator) else { return }
				self?.currentStateSubject.onNext((setBy: next.setBy, state: newState))
				},
			    onError: { [weak self] in
						self?.propagate(error: $0, from: action)
						if let fallback = (action as? RxCompositeAction)?.fallbackAction {
							self?.dispatch(fallback)
						}
					})
			.flatMap { _ in return Observable<Void>.just(()) }
			.catchError { _ in .just(()) }
	}
	
	private func observe(compositeAction: RxCompositeAction) -> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> {
		return Observable.create { [weak self] observer in
			guard let object = self else { return Disposables.create() }

			let scheduledActions = compositeAction.actions.map { action in
				object
					.schedule(actionDescriptor: object.descriptor(for: action, owner: compositeAction), for: action)
					.catchError { .error(FlowControllerError.compositeActionError(erroredAction: action, error: $0)) }
			}

			let disposable = Observable
				.from(scheduledActions)
				.observeOn(object.scheduler)
				.merge(maxConcurrent: 1)
				.observeOn(object.scheduler)
				.do(onNext: { observer.onNext((setBy: $0.setBy, mutator: $0.mutator)) },
				    onError: { observer.onError($0) },
				    onDispose: { observer.onCompleted() })
				.subscribe()
			
			return Disposables.create {
				disposable.dispose()
			}
		}
	}
	
	public func dispatch(_ action: RxActionType) {
		actionsSubject.onNext(action)
	}
}
