//
//  RxStore.swift
//  RxState
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

struct EmptyState : RxStateType { }

public final class RxDataFlowController<State: RxStateType> {
	let bag = DisposeBag()
	let reducer: RxReducerType
	let scheduler: ImmediateSchedulerType
	
	var stateStack: FixedStack<(setBy: RxActionType, state: State)>
	var actionsQueue = Queue<RxActionType>()
	var isActionExecuting = BehaviorSubject(value: false)
	
	let currentStateSubject: BehaviorSubject<(setBy: RxActionType, state: State)>
	let errorsSubject = PublishSubject<(state: RxStateType, action: RxActionType, error: Error)>()
	
	public init(reducer: RxReducerType,
	            initialState: State,
	            maxHistoryItems: UInt = 50,
	            scheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue")) {
		self.scheduler = scheduler
		self.reducer = reducer
		stateStack = FixedStack(capacity: maxHistoryItems)
		stateStack.push((setBy: RxInitialStateAction() as RxActionType, state: initialState))
		
		currentStateSubject = BehaviorSubject(value: (setBy: RxInitialStateAction() as RxActionType, state: initialState))
		currentStateSubject.skip(1).subscribe(onNext: { [weak self] newState in self?.stateStack.push(newState) }).addDisposableTo(bag)
		
		actionsQueue.currentItemSubject.observeOn(scheduler)
			.flatMap { [weak self] action -> Observable<RxStateType> in
				guard let object = self else { return Observable.empty() }
                
                return object.reducer.handle(action, flowController: object).subscribeOn(action.scheduler ?? scheduler)
                    .observeOn(object.scheduler)
                    .do(
                        onNext: { next in
                            object.currentStateSubject.onNext((setBy: action, state: next as! State))
                    },
                        onError: { error in
                            object.errorsSubject.onNext((state: object.stateValue.state, action: action, error: error))
                    },
                        onDispose: { _ in
                            _ = object.actionsQueue.dequeue()
                    }).catchErrorJustReturn(EmptyState())
                /*
                return action.work.schedule(in: object.scheduler, state: object.stateValue.state)
					.observeOn(object.scheduler).flatMapLatest { result -> Observable<RxStateType> in
						return object.reducer.handle(action, actionResult: result, currentState: object.stateStack.peek()!.state)
					}
					.observeOn(object.scheduler)
					.do(
						onNext: { next in
							object.currentStateSubject.onNext((setBy: action, state: next as! State))
						},
						onError: { error in
							object.errorsSubject.onNext((state: object.stateValue.state, action: action, error: error))
						},
						onDispose: { _ in
							_ = object.actionsQueue.dequeue()
					}).catchErrorJustReturn(EmptyState())*/
			}.subscribe().addDisposableTo(bag)
	}
}

extension RxDataFlowController {
	public var state: Observable<(setBy: RxActionType, state: State)> { return currentStateSubject.asObservable().observeOn(scheduler) }
	public var stateValue: (setBy: RxActionType, state: State) { return stateStack.peek()! }
	public var errors: Observable<(state: RxStateType, action: RxActionType, error: Error)> { return errorsSubject }
	
	
	public func dispatch(_ action: RxActionType) {
		scheduler.schedule((action, self)) { params in
			return Observable<Void>.create { observer in
				params.1.actionsQueue.enqueue(params.0)
				return Disposables.create()
				}.subscribe()
			
			}.addDisposableTo(bag)
	}
}
