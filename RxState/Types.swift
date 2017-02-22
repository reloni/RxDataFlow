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

//public protocol RxReducerType {
//	func handle(_ action: RxActionType, actionResult: RxActionResultType, currentState: RxStateType) -> Observable<RxStateType>
//}

public protocol RxReducerType {
    func handle<T: RxStateType>(_ action: RxActionType, flowController: RxDataFlowController<T>) -> Observable<RxStateType>
}
/*
public final class RxActionWork {
	public let workScheduler: ImmediateSchedulerType?
	public let scheduledWork: (RxStateType) -> Observable<RxActionResultType>
	
	public init(scheduler: ImmediateSchedulerType? = nil, scheduledWork: @escaping (RxStateType) -> Observable<RxActionResultType>) {
		self.workScheduler = scheduler
		self.scheduledWork = scheduledWork
	}
	
	public convenience init(scheduler: ImmediateSchedulerType? = nil, scheduledWork: @escaping (RxStateType) -> RxActionResultType) {
		let work: (RxStateType) -> Observable<RxActionResultType> = { state in
			return Observable.create { observer in
				observer.onNext(scheduledWork(state))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		self.init(scheduler: scheduler, scheduledWork: work)
	}
	
	internal func schedule(in outerScheduler: ImmediateSchedulerType, state: RxStateType) -> Observable<RxActionResultType> {
		guard let workScheduler = workScheduler else {
			return scheduledWork(state).subscribeOn(outerScheduler)
		}
		return scheduledWork(state).subscribeOn(workScheduler)
	}
}*/

public protocol RxActionType {
    var scheduler: ImmediateSchedulerType? { get }
}

//public protocol RxActionResultType { }


public struct RxDefaultAction : RxActionType {
    public var scheduler: ImmediateSchedulerType?
}

public struct RxInitialStateAction : RxActionType {
    public var scheduler: ImmediateSchedulerType?
}

//public struct RxDefaultActionResult<T> : RxActionResultType {
//	public let value: T
//	public init(_ value: T) {
//		self.value = value
//	}
//}
