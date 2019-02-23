//
//  Types.swift
//  RxDataFlow
//
//  Created by Anton Efimenko on 23/02/2019.
//  Copyright © 2019 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

typealias Job<State: RxStateType> = Observable<(setBy: RxActionType, mutator: RxStateMutator<State>)>

/**
 Describes type that may be used as state by flow controller
 */
public protocol RxStateType { }

/**
 Function used by flow controller in order to mutate state.
 Flow controller passes current state to function and uses returned instance as new state
 */
public typealias RxStateMutator<State: RxStateType> = (State) -> (State)

/**
 Type returned by reducer function.
 */
public enum RxReduceResult<State: RxStateType> {
    /// Represents error that will be passed to errors Observable
    case error(Error)
    /// Single state mutation
    case single(RxStateMutator<State>)
    /// Represents Observable that may mutate state multiple times
    case observable(Observable<RxStateMutator<State>>)
    /// Empty result, no state changes will occur
    case empty
    
    internal func asObservable() -> Observable<RxStateMutator<State>> {
        switch self {
        case .empty: return .empty()
        case .error(let e): return .error(e)
        case .single(let transform): return .just(transform)
        case .observable(let observable): return observable
        }
    }
}

public extension RxReduceResult {
    /**
     Create new RxReduceResult.observable case from Observable.
     - parameter from: Observable that emits elements
     - parameter transform: Function that transforms current state value and emited element into new state value
     - returns: New RxReduceResult.observable case
     */
    static func create<Result>(from observable: Observable<Result>,
                               transform: @escaping (State, Result) -> State) -> RxReduceResult<State> {
        let map = observable.map { result in
            return { state in
                transform(state, result)
            }
        }
        
        return RxReduceResult.observable(Observable.create { Disposables.create([map.subscribe($0)]) })
    }
}

/**
 Function used by RxDataFlowController in order to change state
 */
public typealias RxReducer<State: RxStateType> = (RxActionType, State) -> RxReduceResult<State>

/**
 Describes action that will be used by flow controller to produce new state
 */
public protocol RxActionType {
    /// Specifies scheduler in which reducer function will be executed. If nil default scheduler will be used
    var scheduler: ImmediateSchedulerType? { get }
    /**
     Specifies is this action serial or not. Flow controller executes serial actions one after another.
     If action takes a long time to complete you may set this property to false and flow controller
     will not wait this action to complete,
     but execute next action immediately.
     */
    var isSerial: Bool { get }
}

public extension RxActionType {
    var scheduler: ImmediateSchedulerType? { return nil }
    var isSerial: Bool { return true }
}

/**
 Special action that useful for grouping actions.
 Actions will be executed one after another, execution will be stoped on error.
 */
public struct RxCompositeAction: RxActionType {
    public let scheduler: ImmediateSchedulerType?
    public let isSerial: Bool
    
    /// Actions to dispatch
    public let actions: [RxActionType]
    
    /// Special action that will be dispatched in case of error
    public let fallbackAction: RxActionType?
    
    public init(actions: [RxActionType],
                fallbackAction: RxActionType? = nil,
                isSerial: Bool = true,
                scheduler: ImmediateSchedulerType? = nil) {
        self.actions = actions
        self.fallbackAction = fallbackAction
        self.isSerial = isSerial
        self.scheduler = scheduler
    }
    
    public init(_ actions: RxActionType..., fallbackAction: RxActionType? = nil,
                isSerial: Bool = true, scheduler: ImmediateSchedulerType? = nil) {
        self.actions = actions
        self.fallbackAction = fallbackAction
        self.isSerial = isSerial
        self.scheduler = scheduler
    }
}

/// Initial action that used for placeholder to set initial state
public struct RxInitializationAction: RxActionType {
    public let isSerial = true
    public var scheduler: ImmediateSchedulerType?
}

enum FlowControllerError: Error {
    case compositeActionError(erroredAction: RxActionType, error: Error)
}

extension SerialDispatchQueueScheduler {
    static var defaultControllerScheduler =
        SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "com.RxDataFlowController.Scheduler")
}
