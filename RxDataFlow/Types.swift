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
    func handle<T: RxStateType>(_ action: RxActionType, flowController: RxDataFlowController<T>) -> Observable<RxStateType>
}

public protocol RxActionType {
    var scheduler: ImmediateSchedulerType? { get }
}

struct EmptyState : RxStateType { }

public struct RxDefaultAction : RxActionType {
    public var scheduler: ImmediateSchedulerType?
}

public struct RxInitialStateAction : RxActionType {
    public var scheduler: ImmediateSchedulerType?
}
