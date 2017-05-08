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

public protocol RxReducerType {
	func handle(_ action: RxActionType, flowController: RxDataFlowControllerType) -> Observable<RxStateType>
}

public protocol RxActionType {
	var scheduler: ImmediateSchedulerType? { get }
	var isSerial: Bool { get }
}

public struct RxCompositeAction : RxActionType {
	public let scheduler: ImmediateSchedulerType?
	public let actions: [RxActionType]
	public let isSerial = true
	public init(actions: [RxActionType], scheduler: ImmediateSchedulerType? = nil) {
		self.actions = actions
		self.scheduler = scheduler
	}
}

public struct RxInitializationAction : RxActionType {
	public let isSerial = true
	public var scheduler: ImmediateSchedulerType?
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
		
	private func subscribe() {
		currentStateSubject.skip(1).subscribe(onNext: { [weak self] newState in self?.stateStack.push(newState) }).disposed(by: bag)
		
		actionsQueue.currentItemSubject.observeOn(serialActionScheduler)
			.flatMap { [weak self] action -> Observable<Void> in
				return self?.observe(action: action) ?? .empty()
			}.subscribe().disposed(by: bag)
	}
	
	private func schedule(actionDescriptor: Observable<(setBy: RxActionType, state: RxStateType)>, for action: RxActionType)
		-> Observable<(setBy: RxActionType, state: RxStateType)> {
			guard !action.isSerial else { return actionDescriptor }
			
			actionDescriptor
				.do(onNext: { [weak self] in self?.currentStateSubject.onNext((setBy: $0.setBy, state: $0.state as! State)) },
				    onError: { [weak self] in
							guard let object = self else { return }
							object.errorsSubject.onNext((state: object.currentState.state, action: action, error: $0))
				})
				.subscribeOn(action.scheduler ?? concurrentActionScheduler)
				.subscribe()
				.disposed(by: bag)
			
			return .empty()
	}
	
	private func observe(action: RxActionType) -> Observable<Void> {
		let descriptor: Observable<(setBy: RxActionType, state: RxStateType)> = { [weak self] in
			guard let object = self else { return .empty() }
			
			let schedulerForAction = action.isSerial ? object.serialActionScheduler : object.concurrentActionScheduler
			
			guard let compositeAction = action as? RxCompositeAction else {
				return Observable<RxActionType>.from([action], scheduler: action.scheduler ?? schedulerForAction)
					.flatMap { act in object.reducer.handle(act, flowController: object).subscribeOn(act.scheduler ?? schedulerForAction) }
					.flatMap { result -> Observable<(setBy: RxActionType, state: RxStateType)> in return .just((setBy: action, state: result)) }
			}
			
			return object.observe(compositeAction: compositeAction)
		}()
		
		return schedule(actionDescriptor: descriptor, for: action)
			.do(onNext: { [weak self] in self?.currentStateSubject.onNext((setBy: $0.setBy, state: $0.state as! State)) },
			    onError: { [weak self] in
						guard let object = self else { return }
						object.errorsSubject.onNext((state: object.currentState.state, action: action, error: $0))
					},
			    onDispose: { [weak self] _ in _ = self?.actionsQueue.dequeue() })
			.flatMap { result -> Observable<RxStateType?> in .just(result.state) }
			.catchErrorJustReturn(nil)
			.flatMap { _ in return Observable<Void>.just() }
	}
	
	private func observe(compositeAction: RxCompositeAction) -> Observable<(setBy: RxActionType, state: RxStateType)> {
		return Observable.create { [weak self] observer in
			guard let object = self else { return Disposables.create() }
			
			var compositeQueue = Queue<RxActionType>()
			
			let disposable = compositeQueue.currentItemSubject.observeOn(object.serialActionScheduler).flatMap { action -> Observable<RxStateType> in
				return Observable.create { _ in
					let subscribsion = Observable.from([action], scheduler: action.scheduler ?? compositeAction.scheduler ?? object.serialActionScheduler)
						.flatMap { act -> Observable<RxStateType> in
							object.reducer.handle(act, flowController: object).subscribeOn(act.scheduler ?? compositeAction.scheduler ?? object.serialActionScheduler)
						}
						.do(onNext: { observer.onNext((setBy: action, state: $0)) },
						    onError: { observer.onError($0) },
						    onCompleted: { _ = compositeQueue.dequeue() },
						    onDispose: { if compositeQueue.count == 0 { observer.onCompleted() } })
						.subscribe()
					return Disposables.create { subscribsion.dispose() }
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
