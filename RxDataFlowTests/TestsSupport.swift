//
//  Support.swift
//  RxDataFlow
//
//  Created by Anton Efimenko on 01.04.17.
//  Copyright © 2017 Anton Efimenko. All rights reserved.
//

import Foundation
@testable import RxDataFlow
import RxSwift
import XCTest

final class TestFlowController<Reducer: RxReducerType> : RxDataFlowController<Reducer> {
	var onDeinit: ((TestFlowController) -> ())?
	deinit {
		onDeinit?(self)
	}
}

final class TestScheduler : ImmediateSchedulerType {
	let internalScheduler: SchedulerType
	var scheduleCounter = 0
	init(internalScheduler: SchedulerType) {
		self.internalScheduler = internalScheduler
	}
	func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
		if state is ScheduledDisposable {
			scheduleCounter += 1
		}
		return internalScheduler.schedule(state, action: action)
	}
}

struct TestState : RxStateType {
	let text: String
}

func testStateDescriptor(text: String) -> (TestState) -> (TestState) {
	return { _ in return TestState(text: text) }
}

struct ChangeTextValueAction : RxActionType {
	let isSerial = true
	let newText: String
	var scheduler: ImmediateSchedulerType?
}

extension ChangeTextValueAction {
	init(newText: String) {
		self.init(newText: newText, scheduler: nil)
	}
}

struct CustomDescriptorAction : RxActionType {
	var scheduler: ImmediateSchedulerType?
	let descriptor: Observable<RxStateMutator<TestState>>
	let isSerial: Bool
}

enum EnumAction : RxActionType {
	case inMainScheduler(Observable<RxStateMutator<TestState>>)
	case inCustomScheduler(ImmediateSchedulerType, Observable<RxStateMutator<TestState>>)
	
	var isSerial: Bool { return true }
	
	var scheduler: ImmediateSchedulerType? {
		switch self {
		case .inMainScheduler: return MainScheduler.instance
		case .inCustomScheduler(let scheduler, _): return scheduler
		}
	}
}

struct CompletionAction : RxActionType {
	var scheduler: ImmediateSchedulerType?
	let isSerial: Bool = true
}

enum TestError : Error {
	case someError
	case otherError
}

struct ErrorAction : RxActionType {
	let isSerial = true
	var scheduler: ImmediateSchedulerType?
}

struct ConcurrentErrorAction : RxActionType {
	let isSerial = false
	var scheduler: ImmediateSchedulerType?
}

struct TestStoreReducer : RxReducerType {
	func handle(_ action: RxActionType, currentState: TestState) -> Observable<RxStateMutator<TestState>> {
		switch action {
		case let a as ChangeTextValueAction: return .just({ _ in return TestState(text: a.newText) }) //return changeTextValue(newText: a.newText)
		case _ as CompletionAction: return .just({ _ in return TestState(text: "Completed") }) //return completion()
		case let a as CustomDescriptorAction: return a.descriptor
		case _ as ErrorAction: return .error(TestError.someError) //return error()
		case _ as ConcurrentErrorAction: return .error(TestError.someError)
		case let enumAction as EnumAction:
			switch enumAction {
			case .inMainScheduler(let descriptor):
				XCTAssertTrue(Thread.isMainThread)
				return descriptor
			case .inCustomScheduler(_, let descriptor):
				XCTAssertFalse(Thread.isMainThread)
				return descriptor
			}
		default: return Observable.empty()
		}
	}
	
	func changeTextValue(newText: String) -> Observable<RxStateType> {
		return .just(TestState(text: newText))
	}
	
	func error() -> Observable<RxStateType> {
		return .error(TestError.someError)
	}
	
	func completion() -> Observable<RxStateType> {
		return .just(TestState(text: "Completed"))
	}
}
