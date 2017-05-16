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

public typealias RxStateMutator = (RxStateType) -> (RxStateType)

public protocol RxReducerType {
	func handle(_ action: RxActionType, flowController: RxDataFlowControllerType) -> Observable<RxStateMutator>
}

public protocol RxActionType {
	var scheduler: ImmediateSchedulerType? { get }
	var isSerial: Bool { get }
}

public struct RxCompositeAction : RxActionType {
	public let scheduler: ImmediateSchedulerType?
	public let actions: [RxActionType]
	public let isSerial: Bool
	
	public init(actions: [RxActionType], isSerial: Bool = true, scheduler: ImmediateSchedulerType? = nil) {
		self.actions = actions
		self.isSerial = isSerial
		self.scheduler = scheduler
	}
	
	public init(_ actions: RxActionType..., isSerial: Bool = true, scheduler: ImmediateSchedulerType? = nil) {
		self.actions = actions
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
	public var state: Observable<(setBy: RxActionType, state: State)> { return currentStateSubject.asObservable().observeOn(serialActionScheduler) }
	public var currentState: (setBy: RxActionType, state: State) { return stateStack.peek()! }
	public var errors: Observable<(state: State, action: RxActionType, error: Error)> { return errorsSubject }
	
	let bag = DisposeBag()
	let reducer: RxReducerType
	let serialActionScheduler: ImmediateSchedulerType
	let concurrentActionScheduler: ImmediateSchedulerType
	
	var stateStack: FixedStack<(setBy: RxActionType, state: State)>
	var actionsQueue = Queue<RxActionType>()
	var isActionExecuting = BehaviorSubject(value: false)
	
	let currentStateSubject: BehaviorSubject<(setBy: RxActionType, state: State)>
	let errorsSubject = PublishSubject<(state: State, action: RxActionType, error: Error)>()
	
	public convenience init(reducer: RxReducerType,
	                        initialState: State,
	                        maxHistoryItems: UInt = 1,
	                        dispatchAction: RxActionType? = nil) {
		self.init(reducer: reducer,
		          initialState: initialState,
		          maxHistoryItems: maxHistoryItems,
		          serialActionScheduler: SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "com.RxDataFlowController.SerialActionScheduler"),
		          concurrentActionScheduler: SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "com.RxDataFlowController.ConcurrentActionScheduler"),
		          dispatchAction: dispatchAction)
	}
	
	init(reducer: RxReducerType,
	     initialState: State,
	     maxHistoryItems: UInt = 50,
	     serialActionScheduler: ImmediateSchedulerType,
	     concurrentActionScheduler: ImmediateSchedulerType,
	     dispatchAction: RxActionType? = nil) {
		self.serialActionScheduler = serialActionScheduler
		self.concurrentActionScheduler = concurrentActionScheduler
		self.reducer = reducer
		stateStack = FixedStack(capacity: maxHistoryItems)
		stateStack.push((setBy: RxInitializationAction(), state: initialState))
		
		currentStateSubject = BehaviorSubject(value: (setBy: RxInitializationAction(), state: initialState))
		
		subscribe()
		
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
		return actionScheduler ?? (action.isSerial ? serialActionScheduler : concurrentActionScheduler)
	}
	
	private func descriptor(for action: RxActionType, owner: RxCompositeAction? = nil) -> Observable<(setBy: RxActionType, mutator: RxStateMutator)> {
		let schedulerForAction = scheduler(for: action, owner: owner)
		let object = self
		return Observable<RxActionType>.from([action], scheduler: schedulerForAction)
			.flatMap { act in object.reducer.handle(act, flowController: object).subscribeOn(schedulerForAction) }
			.observeOn(schedulerForAction)
			.flatMap { result -> Observable<(setBy: RxActionType, mutator: RxStateMutator)> in return .just((setBy: action, mutator: result)) }
	}
	
	private func subscribe() {
		currentStateSubject.skip(1).subscribe(onNext: { [weak self] newState in self?.stateStack.push(newState) }).disposed(by: bag)
		
		actionsQueue.currentItemSubject.observeOn(serialActionScheduler)
			.flatMap { [weak self] action -> Observable<Void> in
				return self?.observe(action: action) ?? .empty()
			}.subscribe().disposed(by: bag)
	}
	
	private func mutateState(with mutator: RxStateMutator) -> State {
		return mutator(currentState.state) as! State
	}
	
	private func schedule(actionDescriptor: Observable<(setBy: RxActionType, mutator: RxStateMutator)>, for action: RxActionType)
		-> Observable<(setBy: RxActionType, mutator: RxStateMutator)> {
			guard !action.isSerial else { return actionDescriptor.observeOn(serialActionScheduler) }
			
			actionDescriptor
				.observeOn(serialActionScheduler)
				.do(onNext: { [weak self] next in
					guard let newState = self?.mutateState(with: next.mutator) else { return }
					self?.currentStateSubject.onNext((setBy: next.setBy, state: newState))
					},
				    onError: { [weak self] in self?.propagate(error: $0, from: action) })
				.subscribeOn(action.scheduler ?? concurrentActionScheduler)
				.subscribe()
				.disposed(by: bag)
			
			return .empty()
	}
	
	private func observe(action: RxActionType) -> Observable<Void> {
		let descriptor: Observable<(setBy: RxActionType, mutator: RxStateMutator)> = { [weak self] in
			guard let object = self else { return .empty() }
			
			guard let compositeAction = action as? RxCompositeAction else {
				return object.descriptor(for: action)
			}
			
			return object.observe(compositeAction: compositeAction)
		}()
		
		return schedule(actionDescriptor: descriptor, for: action)
			.observeOn(serialActionScheduler)
			.do(onNext: { [weak self] next in
				guard let newState = self?.mutateState(with: next.mutator) else { return }
				self?.currentStateSubject.onNext((setBy: next.setBy, state: newState))
				},
			    onError: { [weak self] in self?.propagate(error: $0, from: action) },
			    onDispose: { [weak self] _ in _ = self?.actionsQueue.dequeue() })
//			.flatMap { result -> Observable<RxStateType?> in .just(result.state) }
//			.catchErrorJustReturn(nil)
			.flatMap { _ in return Observable<Void>.just() }
			.catchError { _ in .just() }
	}
	
	private func observe(compositeAction: RxCompositeAction) -> Observable<(setBy: RxActionType, mutator: RxStateMutator)> {
		return Observable.create { [weak self] observer in
			guard let object = self else { return Disposables.create() }
			
			var compositeQueue = Queue<RxActionType>()
			
			let disposable = compositeQueue.currentItemSubject.observeOn(object.serialActionScheduler).flatMap { action -> Observable<RxStateType> in
				return Observable.create { _ in
					let descriptor = object.descriptor(for: action, owner: compositeAction).catchError { error -> Observable<(setBy: RxActionType, mutator: RxStateMutator)> in
						return .error(FlowControllerError.compositeActionError(erroredAction: action, error: error))
					}
					let subscription = object.schedule(actionDescriptor: descriptor, for: action)
						.observeOn(object.serialActionScheduler)
						.do(onNext: { observer.onNext((setBy: $0.setBy, mutator: $0.mutator)) },
						    onError: { observer.onError($0) },
						    onCompleted: { _ = compositeQueue.dequeue() },
						    onDispose: { if compositeQueue.count == 0 { observer.onCompleted() } })
						.subscribe()
					return Disposables.create { subscription.dispose() }
				}
			}.subscribe()
			
			for a in compositeAction.actions { compositeQueue.enqueue(a) }
			
			return Disposables.create {
				disposable.dispose()
			}
		}
	}
	
	public func dispatch(_ action: RxActionType) {
		serialActionScheduler.schedule((action, self)) { params in
			return Observable<Void>.create { observer in
				params.1.actionsQueue.enqueue(params.0)
				return Disposables.create()
				}.subscribe()
			}.disposed(by: bag)
	}
}
