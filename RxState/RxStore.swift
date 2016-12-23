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

public final class RxStore<State: RxStateType> {
	let bag = DisposeBag()
    let reducer: RxReducerType
    let scheduler = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue")
    
    var stateStack: FixedStack<(setBy: RxActionType, state: State)>
	var actionsQueue = Queue<RxActionType>()
    var isActionExecuting = BehaviorSubject(value: false)
    
	let currentStateSubject: BehaviorSubject<(setBy: RxActionType, state: State)>
	let errorsSubject = PublishSubject<(state: RxStateType, action: RxActionType, error: Error)>()
	
	public init(reducer: RxReducerType, initialState: State, maxHistoryItems: UInt = 50) {
		self.reducer = reducer
		stateStack = FixedStack(capacity: maxHistoryItems)

		currentStateSubject = BehaviorSubject(value: (setBy: RxInitialStateAction() as RxActionType, state: initialState))
		currentStateSubject.subscribe(onNext: { [unowned self] newState in self.stateStack.push(newState) }).addDisposableTo(bag)
        
        actionsQueue.currentItemSubject.observeOn(scheduler)
            .flatMap { [unowned self] action -> Observable<RxStateType> in
                return action.work(self.stateValue.state)
                    .subscribeOn(self.scheduler).observeOn(self.scheduler).flatMapLatest { [unowned self] result -> Observable<RxStateType> in
                    return self.reducer.handle(action, actionResult: result, currentState: self.stateStack.peek()!.state)
                    }
                    .observeOn(self.scheduler)
                    .do(
                        onNext: { [unowned self] next in
                            self.currentStateSubject.onNext((setBy: action, state: next as! State))
                        },
                        onError: { [unowned self] error in
                            self.errorsSubject.onNext((state: self.stateValue.state, action: action, error: error))
                        },
                        onDispose: { [unowned self] in
                            _ = self.actionsQueue.dequeue()
                    }).catchErrorJustReturn(EmptyState())
            }.subscribe().addDisposableTo(bag)
	}
}

extension RxStore {
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
