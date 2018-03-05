//
//  RxDataFlowController.swift
//  RxState
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

/**
Describes type that may be used as state by flow controller
*/
public protocol RxStateType { }

/**
Function used by flow controller in order to mutate state.
Flow controller passes current state to function and uses returned instance as new state
*/
public typealias RxStateMutator<State: RxStateType> = (State) -> (State)

/**
*/
public typealias RxReducer<State: RxStateType> = (RxActionType, State) -> Observable<RxStateMutator<State>>

/**
Describes action that will be used by flow controller to produce new state
*/
public protocol RxActionType {
	/// Specifies scheduler in which reducer function will be executed. If nil default scheduler will be used
	var scheduler: ImmediateSchedulerType? { get }
	/**
	Specifies is this action serial or not. Flow controller executes serial actions one after another. 
	If action takes a long time to complete you may set this property to false and flow controller
	will not wait this action to complete,
	but execute next action immediately.
	*/
	var isSerial: Bool { get }
}

/**
Special action that useful for grouping actions.
Actions will be executed one after another, execution will be stoped on error.
*/
public struct RxCompositeAction: RxActionType {
	public let scheduler: ImmediateSchedulerType?
	public let isSerial: Bool

	/// Actions to dispatch
	public let actions: [RxActionType]

	/// Special action that will be dispatched in case of error
	public let fallbackAction: RxActionType?

	public init(actions: [RxActionType],
	            fallbackAction: RxActionType? = nil,
	            isSerial: Bool = true,
	            scheduler: ImmediateSchedulerType? = nil) {
		self.actions = actions
		self.fallbackAction = fallbackAction
		self.isSerial = isSerial
		self.scheduler = scheduler
	}

	public init(_ actions: RxActionType..., fallbackAction: RxActionType? = nil,
	            isSerial: Bool = true, scheduler: ImmediateSchedulerType? = nil) {
		self.actions = actions
		self.fallbackAction = fallbackAction
		self.isSerial = isSerial
		self.scheduler = scheduler
	}
}

/// Initial action that used for placeholder to set initial state
public struct RxInitializationAction: RxActionType {
	public let isSerial = true
	public var scheduler: ImmediateSchedulerType?
}

enum FlowControllerError: Error {
	case compositeActionError(erroredAction: RxActionType, error: Error)
}

public class RxDataFlowController<State: RxStateType> {
	/**
	Observable sequence that emits new state changes
	*/
	public var state: Observable<(setBy: RxActionType, state: State)> {
		return currentStateSubject.asObservable().startWith(currentState).observeOn(scheduler)
	}
	
	/**
	Returns current state
	*/
	public private(set) var currentState: (setBy: RxActionType, state: State) {
		didSet { currentStateSubject.onNext(currentState) }
	}
	
	/**
	Observable sequence that emits errors
	*/
	public var errors: Observable<(state: State, action: RxActionType, error: Error)> { return errorsSubject }
	
	let bag = DisposeBag()
	let reducer: RxReducer<State>
	let scheduler: ImmediateSchedulerType
	
	var actionsQueue = Queue<RxActionType>()
	
	let currentStateSubject = PublishSubject<(setBy: RxActionType, state: State)>()
	let errorsSubject = PublishSubject<(state: State, action: RxActionType, error: Error)>()
	
	/**
	Initialized new instance of RxDataFlowController
	- parameter reducer: Reducer-function that will be executed for produce a new state
	- parameter initialState: Initial state instance
	- dispatchAction: Action that will be dispatched immediately after initialization
	*/
	public convenience init(
		reducer: @escaping RxReducer<State>,
		initialState: State,
		dispatchAction: RxActionType? = nil) {
		self.init(reducer: reducer,
				  initialState: initialState,
				  scheduler: SerialDispatchQueueScheduler(qos: .userInitiated,
														  internalSerialQueueName: "com.RxDataFlowController.Scheduler"),
				  dispatchAction: dispatchAction)
	}
	
	init(
		reducer: @escaping RxReducer<State>,
		initialState: State,
		scheduler: ImmediateSchedulerType,
		dispatchAction: RxActionType? = nil) {
		self.scheduler = scheduler
		self.reducer = reducer//AnyRxReducer(reducer: reducer)
		
		currentState = (setBy: RxInitializationAction(), state: initialState)
		
		actionsQueue.currentItemSubject.observeOn(scheduler)
			.flatMap { [weak self] action -> Observable<Void> in
				return self?.observe(action: action) ?? .empty()
			}.subscribe().disposed(by: bag)
		
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
	
	private func descriptor(for action: RxActionType, owner: RxCompositeAction? = nil)
		-> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> {
		let schedulerForAction = scheduler(for: action, owner: owner)
		let object = self
		return Observable<RxActionType>.from([action], scheduler: schedulerForAction)
			.flatMap { act in object.reducer(act, object.currentState.state).subscribeOn(schedulerForAction) }
			.observeOn(schedulerForAction)
			.flatMap { result -> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> in
				return .just((setBy: action, mutator: result))
		}
	}

	private func mutateState(with mutator: RxStateMutator<State>) -> State {
		return mutator(currentState.state)
	}
	
	private func schedule(
		actionDescriptor: Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)>,
		for action: RxActionType)
		-> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> {
			guard !action.isSerial else { return actionDescriptor.observeOn(scheduler) }
			
			actionDescriptor
				.observeOn(scheduler)
				.do(onNext: { [weak self] next in
					guard let newState = self?.mutateState(with: next.mutator) else { return }
					self?.currentState = (setBy: next.setBy, state: newState)
					},
					onError: { [weak self] in self?.propagate(error: $0, from: action) })
				.subscribeOn(action.scheduler ?? scheduler)
				.subscribe()
				.disposed(by: bag)
			
			return .empty()
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
				self?.currentState = (setBy: next.setBy, state: newState)
				},
				onError: { [weak self] in
					self?.propagate(error: $0, from: action)
					if let fallback = (action as? RxCompositeAction)?.fallbackAction {
						self?.dispatch(fallback)
					}
				},
				onDispose: { [weak self] in _ = self?.actionsQueue.dequeue() })
			.flatMap { _ in return Observable<Void>.just(()) }
			.catchError { _ in .just(()) }
	}
	
	private func observe(compositeAction: RxCompositeAction)
		-> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> {
		return Observable.create { [weak self] observer in
			guard let object = self else { return Disposables.create() }
			
			var compositeQueue = Queue<RxActionType>()
			
			let disposable = compositeQueue.currentItemSubject
				.observeOn(object.scheduler)
				.flatMap { action -> Observable<RxStateType> in
				return Observable.create { _ in
					let descriptor = object
						.descriptor(for: action, owner: compositeAction)
						.catchError { error -> Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)> in
						return .error(FlowControllerError.compositeActionError(erroredAction: action, error: error))
					}
					let subscription = object.schedule(actionDescriptor: descriptor, for: action)
						.observeOn(object.scheduler)
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
	
	/**
	Dispatches an action.
	Example of dispatching an action:
	```
	let data = ...
	controller.dispatch(DataAction.updateData(data))
	```
	- parameter action: The action that is being dispatched by controller
	*/
	public func dispatch(_ action: RxActionType) {
		scheduler.schedule((action, self)) { params in
			return Observable<Void>.create { observer in
				params.1.actionsQueue.enqueue(params.0)
				observer.onCompleted()
				return Disposables.create()
				}.subscribe()
			}.disposed(by: bag)
	}
    
    /**
     Dispatches an action after specified DispatchTimeInterval.
     This is a simple wrapper over DispatchQueue.asyncAfter(deadline: execute:) function
     Example of dispatching an action:
     ```
     let data = ...
     controller.dispatchAfter(.seconds(1), action: DataAction.updateData(data))
     // action will be dispatched after 1 second
     ```
     - parameter action: The action that is being dispatched by controller
     */
    public func dispatchAfter(_ interval: DispatchTimeInterval, action: RxActionType) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + interval) {
            self.dispatch(action)
        }
    }
}
