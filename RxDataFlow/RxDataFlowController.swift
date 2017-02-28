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
}

public protocol RxCompositeActionType : RxActionType {
	var actions: [RxActionType] { get }
}

public struct RxInitializationAction : RxActionType {
	public var scheduler: ImmediateSchedulerType?
}


public final class RxDataFlowController<State: RxStateType> : RxDataFlowControllerType {
	public var state: Observable<(setBy: RxActionType, state: State)> { return currentStateSubject.asObservable().observeOn(scheduler) }
	public var currentState: (setBy: RxActionType, state: State) { return stateStack.peek()! }
	public var errors: Observable<(state: State, action: RxActionType, error: Error)> { return errorsSubject }
	
	let bag = DisposeBag()
	let reducer: RxReducerType
	let scheduler: ImmediateSchedulerType
	
	var stateStack: FixedStack<(setBy: RxActionType, state: State)>
	var actionsQueue = Queue<RxActionType>()
	var isActionExecuting = BehaviorSubject(value: false)
	
	let currentStateSubject: BehaviorSubject<(setBy: RxActionType, state: State)>
	let errorsSubject = PublishSubject<(state: State, action: RxActionType, error: Error)>()
	
	public init(reducer: RxReducerType,
	            initialState: State,
	            maxHistoryItems: UInt = 50,
	            scheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue"),
	            dispatchAction: RxActionType? = nil) {
		self.scheduler = scheduler
		self.reducer = reducer
		stateStack = FixedStack(capacity: maxHistoryItems)
		stateStack.push((setBy: RxInitializationAction(), state: initialState))
		
		currentStateSubject = BehaviorSubject(value: (setBy: RxInitializationAction(), state: initialState))
		
		subscribe()
		
		if let dispatchAction = dispatchAction {
			dispatch(dispatchAction)
		}
	}
	
	static func sync(compositeAction action: RxCompositeActionType, flowController: RxDataFlowController<State>) -> Observable<RxStateType> {
		return Observable.create { observer in
			var queue = Queue<RxActionType>()
			
			let disposable = queue.currentItemSubject.observeOn(flowController.scheduler).flatMap { action -> Observable<RxStateType> in
				return Observable.create { _ in
					
					//let obs = flowController.reducer.handle(action, flowController: flowController).subscribeOn(action.scheduler ?? flowController.scheduler)
					let obs = Observable.from([action], scheduler: action.scheduler ?? flowController.scheduler)
						.flatMap { a -> Observable<RxStateType> in flowController.reducer.handle(action, flowController: flowController).subscribeOn(action.scheduler ?? flowController.scheduler) }
						.do(
							onNext: { observer.onNext($0) },
							onError: { observer.onError($0) },
							onCompleted: {
								print("COMPLETE!!!!!")
								_ = queue.dequeue()
								//if queue.dequeue() == nil { print("COMPLETE!!!!!");o.onCompleted() }
						},
							onDispose: {
								print("DISPOSE!!!!!")
								if queue.count == 0 {
									print("EMPTY!!!!!")
									observer.onCompleted()
								}
								//if queue.dequeue() == nil { print("DISPOSE!!!!!");o.onCompleted() }
						})
						.subscribe()
					return Disposables.create { obs.dispose() }
				}
			}.subscribe()
			
			//flowController.reducer.handle(action, flowController: flowController)
			//}.do(onNext: { observer.onNext($0) }, onError: { observer.onError($0) }, onDispose: { _ = queue.dequeue() }).subscribe()
			
			for a in action.actions { queue.enqueue(a) }
			
			return Disposables.create { disposable.dispose() }
		}
		
	}
	
	private func subscribe() {
		currentStateSubject.skip(1).subscribe(onNext: { [weak self] newState in self?.stateStack.push(newState) }).addDisposableTo(bag)
		
		actionsQueue.currentItemSubject.observeOn(scheduler)
			.flatMap { [weak self] action -> Observable<RxStateType?> in
				guard let object = self else { return Observable.empty() }
				
//				let handle: Observable<RxStateType> = {
//					let actions: Observable<RxActionType> = {
//						guard let compositeAction = action as? RxCompositeActionType else {
//							return Observable.from([action], scheduler: action.scheduler ?? object.scheduler)
//						}
//						
//						return Observable.from(compositeAction.actions, scheduler: action.scheduler ?? object.scheduler)
//						
//						//                        return Observable.from(compositeAction.actions).observeOn(object.scheduler)
//						//                            .flatMap { Observable.from([$0], scheduler: $0.scheduler ?? object.scheduler) }
//						
//						//return Observable.from(compositeAction.actions.map { Observable.from([$0], scheduler: $0.scheduler ?? object.scheduler) })
//						//	.flatMap { $0 }
//					}()
//					
//					return actions.flatMap { a -> Observable<RxStateType> in
//						return object.reducer.handle(a, flowController: object)
//							.subscribeOn(a.scheduler ?? object.scheduler).observeOn(a.scheduler ?? object.scheduler)
//					}
//				}()
				
				let handle: Observable<RxStateType> = {
					guard let compositeAction = action as? RxCompositeActionType else {
						return Observable.from([action], scheduler: action.scheduler ?? object.scheduler)
							.flatMap { a -> Observable<RxStateType> in object.reducer.handle(action, flowController: object).subscribeOn(action.scheduler ?? object.scheduler) }
//						return object.reducer.handle(action, flowController: object)
//													.subscribeOn(action.scheduler ?? object.scheduler).observeOn(action.scheduler ?? object.scheduler)
					}
					return RxDataFlowController.sync(compositeAction: compositeAction, flowController: object)
				}()
				
				return handle
					.do(
						onNext: { next in
							object.currentStateSubject.onNext((setBy: action, state: next as! State))
					},
						onError: { error in
							object.errorsSubject.onNext((state: object.currentState.state, action: action, error: error))
					},
						onDispose: { _ in
							_ = object.actionsQueue.dequeue()
					})
					.flatMap { result -> Observable<RxStateType?> in .just(result) }
					.catchErrorJustReturn(nil)
			}.subscribe().addDisposableTo(bag)
	}
	
	public func dispatch(_ action: RxActionType) {
		scheduler.schedule((action, self)) { params in
			return Observable<Void>.create { observer in
				params.1.actionsQueue.enqueue(params.0)
				return Disposables.create()
				}.subscribe()
			}.addDisposableTo(bag)
	}
}
