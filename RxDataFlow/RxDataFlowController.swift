//
//  RxDataFlowController.swift
//  RxState
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

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
	- parameter dispatchAction: Action that will be dispatched immediately after initialization
    - parameter defaultScheduler: Default scheduler that will be used for dispatching actions.
     If not specified, will be used scheduler with userInitiated quality of service.
	*/
    public convenience init(
        reducer: @escaping RxReducer<State>,
        initialState: State,
        dispatchAction: RxActionType? = nil,
        defaultScheduler: SerialDispatchQueueScheduler? = nil) {
        self.init(reducer: reducer,
                  initialState: initialState,
                  scheduler: defaultScheduler ?? SerialDispatchQueueScheduler.defaultControllerScheduler,
                  dispatchAction: dispatchAction)
    }
	
	init(
		reducer: @escaping RxReducer<State>,
		initialState: State,
		scheduler: ImmediateSchedulerType,
		dispatchAction: RxActionType? = nil) {
		self.scheduler = scheduler
		self.reducer = reducer
		
		currentState = (setBy: RxInitializationAction(), state: initialState)
		
		actionsQueue
            .currentItemSubject
            .observeOn(scheduler)
			.flatMap { [weak self] action -> Completable in self?.observe(action: action) ?? .empty() }
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
    
    private func mutateState(with mutator: RxStateMutator<State>) -> State {
        return mutator(currentState.state)
    }
    
    private func setCurrentState(by action: RxActionType, with mutator: RxStateMutator<State>) {
        currentState = (setBy: action, state: mutateState(with: mutator))
    }
	
	private func schedule(actionJob: Job<State>, for action: RxActionType) -> Job<State> {
			guard !action.isSerial else { return actionJob.observeOn(scheduler) }
			
			actionJob
				.observeOn(scheduler)
				.do(onNext: { [weak self] in self?.setCurrentState(by: $0, with: $1) },
					onError: { [weak self] in self?.propagate(error: $0, from: action) })
				.subscribeOn(action.scheduler ?? scheduler)
				.subscribe()
				.disposed(by: bag)
			
			return .empty()
	}
	
	private func observe(action: RxActionType) -> Completable {
		let job: Job<State> = { [weak self] in
			guard let self = self else { return .empty() }
			
			guard let compositeAction = action as? RxCompositeAction else {
				return self.job(forAction: action)
			}
			
			return self.job(forCompositeAction: compositeAction)
        }()
		
		return schedule(actionJob: job, for: action)
			.observeOn(scheduler)
			.do(onNext: { [weak self] in self?.setCurrentState(by: $0, with: $1) },
				onError: { [weak self] in
                    self?.propagate(error: $0, from: action)
                    if let fallback = (action as? RxCompositeAction)?.fallbackAction {
                        self?.dispatch(fallback)
                    }
				},
				onDispose: { [weak self] in _ = self?.actionsQueue.dequeue() })
			.ignoreElements()
            .catchError { _ in .empty() }
	}
    
    private func job(forAction action: RxActionType, owner: RxCompositeAction? = nil) -> Job<State> {
        let schedulerForAction = scheduler(for: action, owner: owner)
        
        return Observable<RxActionType>.from([action], scheduler: schedulerForAction)
            .flatMap { act in self.reducer(act, self.currentState.state).asObservable().subscribeOn(schedulerForAction) }
            .observeOn(schedulerForAction)
            .flatMap { result -> Job<State> in return .just((setBy: action, mutator: result)) }
    }
	
	private func job(forCompositeAction compositeAction: RxCompositeAction) -> Job<State> {
		return Observable.create { [weak self] observer in
			guard let object = self else { return Disposables.create() }
			
			var compositeQueue = Queue<RxActionType>()
			
			let disposable = compositeQueue.currentItemSubject.observeOn(object.scheduler).flatMap { action -> Observable<RxStateType> in
				return Observable.create { _ in
                    let job = object
                        .job(forAction: action, owner: compositeAction)
                        .catchError { .error(FlowControllerError.compositeActionError(erroredAction: action, error: $0)) }
                    
					let subscription = object.schedule(actionJob: job, for: action)
						.observeOn(object.scheduler)
						.do(onNext: { observer.onNext((setBy: $0.setBy, mutator: $0.mutator)) },
							onError: { observer.onError($0) },
							onCompleted: { _ = compositeQueue.dequeue() },
							onDispose: { if compositeQueue.count == 0 { observer.onCompleted() } })
						.subscribe()
					return Disposables.create { subscription.dispose() }
				}
            }.subscribe()
			
			compositeAction.actions.forEach { compositeQueue.enqueue($0) }
			
			return Disposables.create { disposable.dispose() }
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
}
