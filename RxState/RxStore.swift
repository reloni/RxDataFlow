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
	let currentStateVariable: Variable<(setBy: RxActionType, state: State)>
	let errorsSubject = PublishSubject<(state: RxStateType, action: RxActionType, error: Error)>()
	let reducer: RxReducerType
	let dispatcher = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue")
	
	public init(reducer: RxReducerType, initialState: State) {
		self.reducer = reducer
		currentStateVariable = Variable((setBy: RxInitialStateAction() as RxActionType, state: initialState))
	}
	
	public func dispatch(_ action: RxActionType) -> Observable<Void> {
		return Observable.combineLatest(Observable.just(currentStateVariable.value.state),
		                                Observable.just(reducer),
		                                action.work(currentStateVariable.value.state).subscribeOn(dispatcher).observeOn(dispatcher)) { currentState, currentReducer, actionResult in
																			return currentReducer.handle(action, actionResult: actionResult, currentState: currentState)
			}
			.flatMap { newState -> Observable<RxStateType> in return newState }
			.flatMap { [weak self] newState -> Observable<Void> in
				self?.currentStateVariable.value = (setBy: action, state: newState as! State)
				return Observable.just()
		}
			.do(onError: { [weak self] error in
				guard let object = self else { return }
				object.errorsSubject.onNext((state: object.stateValue.state, action: action, error: error))
			})
			.observeOn(dispatcher)
	}
	
	public var state: Observable<(setBy: RxActionType, state: State)> { return currentStateVariable.asObservable().observeOn(dispatcher) }
	public var stateValue: (setBy: RxActionType, state: State) { return currentStateVariable.value }
	
	public var errors: Observable<(state: RxStateType, action: RxActionType, error: Error)> { return errorsSubject }
}
