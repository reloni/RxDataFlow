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
	func handle(_ action: RxActionType, state: RxStateType) -> Observable<RxStateType>
}
public protocol RxActionType { }

public final class RxStore<State: RxStateType> {
	let currentState: Variable<State>
	let reducer: RxReducerType
	let dispatcher = SerialDispatchQueueScheduler(qos: .utility, internalSerialQueueName: "RxStore.DispatchQueue")
	
	public init(reducer: RxReducerType, initialState: State) {
		self.reducer = reducer
		currentState = Variable(initialState)
	}
	
	public func dispatch(_ action: RxActionType) -> Disposable {
		return reducer.handle(action, state: currentState.value).subscribeOn(dispatcher)
			.do(onNext: { [weak self] next in self?.currentState.value = next as! State }).subscribe()
	}
	
	public var state: Observable<State> { return currentState.asObservable().observeOn(dispatcher) }
}
