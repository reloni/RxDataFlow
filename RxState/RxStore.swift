//
//  RxStore.swift
//  RxState
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

public protocol RxStateType { }
public protocol RxReducerType {
	func handle(_ action: RxActionType, actionResult: RxActionResultType, currentState: RxStateType) -> Observable<RxStateType>
}
public protocol RxActionType {
	var work: () -> Observable<RxActionResultType> { get }
}
public protocol RxActionResultType { }

public struct InitialStateAction : RxActionType {
	public var work: () -> Observable<RxActionResultType> {
		return {
			return Observable<RxActionResultType>.empty()
		}
	}
}

public struct DefaultActionResult<T> : RxActionResultType {
	public let value: T
	public init(_ value: T) {
		self.value = value
	}
}

public final class RxStore<State: RxStateType> {
	let currentStateVariable: Variable<(setBy: RxActionType, state: State)>
	let reducer: RxReducerType
	let dispatcher = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue")
	
	public init(reducer: RxReducerType, initialState: State) {
		self.reducer = reducer
		currentStateVariable = Variable((setBy: InitialStateAction() as RxActionType, state: initialState))
	}
	
	public func dispatch(_ action: RxActionType) -> Disposable? {
		return action.work().observeOn(dispatcher).flatMapLatest { [weak self] result -> Observable<RxStateType> in
			guard let currentState = self?.currentStateVariable.value else { return Observable.empty() }
			return self?.reducer.handle(action, actionResult: result, currentState: currentState.state) ?? Observable.empty()
			}
			.observeOn(dispatcher)
			.subscribe(onNext: { [weak self] next in
				self?.currentStateVariable.value = (setBy: action, state: next as! State)
			})
	}
	
	public var state: Observable<(setBy: RxActionType, state: State)> { return currentStateVariable.asObservable().observeOn(dispatcher) }
	public var stateValue: (setBy: RxActionType, state: State) { return currentStateVariable.value }
}
