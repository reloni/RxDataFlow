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
	            scheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue")) {
		self.scheduler = scheduler
		self.reducer = reducer
		stateStack = FixedStack(capacity: maxHistoryItems)
		stateStack.push((setBy: RxInitialStateAction() as RxActionType, state: initialState))
		
		currentStateSubject = BehaviorSubject(value: (setBy: RxInitialStateAction() as RxActionType, state: initialState))
		
		subscribe()
	}
	
	private func subscribe() {
		currentStateSubject.skip(1).subscribe(onNext: { [weak self] newState in self?.stateStack.push(newState) }).addDisposableTo(bag)
		
		actionsQueue.currentItemSubject.observeOn(scheduler)
			.flatMap { [weak self] action -> Observable<RxStateType?> in
				guard let object = self else { return Observable.empty() }
				
				let handle = Observable<RxStateType>.create { observer in
					let disposable = object.reducer.handle(action, flowController: object).subscribe(observer)
					return Disposables.create { disposable.dispose() }
				}
				
				return handle.subscribeOn(action.scheduler ?? object.scheduler)
					.observeOn(object.scheduler)
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
