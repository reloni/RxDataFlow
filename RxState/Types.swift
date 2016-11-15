//
//  Types.swift
//  RxState
//
//  Created by Anton Efimenko on 06.11.16.
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

public struct RxDefaultAction : RxActionType {
	public var work: () -> Observable<RxActionResultType>
}

public struct RxInitialStateAction : RxActionType {
	public var work: () -> Observable<RxActionResultType> {
		return {
			return Observable<RxActionResultType>.empty()
		}
	}
}

public struct RxDefaultActionResult<T> : RxActionResultType {
	public let value: T
	public init(_ value: T) {
		self.value = value
	}
}
