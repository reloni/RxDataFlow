//
//  RxStore.swift
//  RxState
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

public final class RxStore<State: RxStateType> {
	let bag = DisposeBag()
	var actionsQueue = Queue<RxActionType>()
	let currentStateSubject: BehaviorSubject<(setBy: RxActionType, state: State)>
	
	let errorsSubject = PublishSubject<(state: RxStateType, action: RxActionType, error: Error)>()

	let reducer: RxReducerType
	let scheduler = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue")
	var stateStack: FixedStack<(setBy: RxActionType, state: State)>
	
	public init(reducer: RxReducerType, initialState: State, maxHistoryItems: UInt = 50) {
		self.reducer = reducer
		stateStack = FixedStack(capacity: maxHistoryItems)

		currentStateSubject = BehaviorSubject(value: (setBy: RxInitialStateAction() as RxActionType, state: initialState))
		currentStateSubject.subscribe(onNext: { [unowned self] newState in self.stateStack.push(newState) }).addDisposableTo(bag)
	}
}

extension RxStore {
	public var state: Observable<(setBy: RxActionType, state: State)> { return currentStateSubject.asObservable().observeOn(scheduler) }
	public var stateValue: (setBy: RxActionType, state: State) { return stateStack.peek()! }
	public var errors: Observable<(state: RxStateType, action: RxActionType, error: Error)> { return errorsSubject }
	
	func dequeueAction() -> Observable<RxActionType> {
		return Observable.create { [unowned self] observer in
			guard let action = self.actionsQueue.dequeue() else { observer.onCompleted(); return Disposables.create() }
			observer.onNext(action)
			observer.onCompleted()
			return Disposables.create()
		}.subscribeOn(scheduler).observeOn(scheduler)
	}
	
	func dispatch() {
		dequeueAction().flatMap { [unowned self] action -> Observable<RxStateType> in
			return action.work(self.stateValue.state).subscribeOn(self.scheduler).observeOn(self.scheduler).flatMapLatest { [unowned self] result -> Observable<RxStateType> in
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
					onDispose: { [unowned self] in self.dispatch() })
		}.subscribe().addDisposableTo(bag)
		
//		action.work(stateValue.state).subscribeOn(scheduler).observeOn(scheduler).flatMapLatest { [unowned self] result -> Observable<RxStateType> in
//			return self.reducer.handle(action, actionResult: result, currentState: self.stateStack.peek()!.state)
//			}
//			.observeOn(scheduler)
//			.subscribe(
//				onNext: { [unowned self] next in
//					self.currentStateSubject.onNext((setBy: action, state: next as! State))
//				},
//				onError: { [unowned self] error in
//					self.errorsSubject.onNext((state: self.stateValue.state, action: action, error: error))
//				},
//				onDisposed: {  }).addDisposableTo(bag)
	}

	public func dispatch(_ action: RxActionType) {
		action.work(stateValue.state).subscribeOn(scheduler).observeOn(scheduler).flatMapLatest { [unowned self] result -> Observable<RxStateType> in
			return self.reducer.handle(action, actionResult: result, currentState: self.stateStack.peek()!.state)
			}
			.observeOn(scheduler)
			.subscribe(
				onNext: { [unowned self] next in
					self.currentStateSubject.onNext((setBy: action, state: next as! State))
				},
				onError: { [unowned self] error in
					self.errorsSubject.onNext((state: self.stateValue.state, action: action, error: error))
			}).addDisposableTo(bag)
	}
}
