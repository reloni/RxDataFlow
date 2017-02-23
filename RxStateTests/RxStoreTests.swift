//
//  RxStoreTests.swift
//  RxStateTests
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import XCTest
import RxSwift
@testable import RxState

struct TestState : RxStateType {
	let text: String
}

struct ChangeTextValueAction : RxActionType {
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
	let descriptor: Observable<RxStateType>
}

struct CompletionAction : RxActionType {
	var scheduler: ImmediateSchedulerType?
}

enum TestError : Error {
	case someError
}

struct ErrorAction : RxActionType {
	var scheduler: ImmediateSchedulerType?
}

struct TestStoreReducer : RxReducerType {
	typealias T = TestState
	func handle<T : RxStateType>(_ action: RxActionType, flowController: RxDataFlowController<T>) -> Observable<RxStateType> {
		switch action {
		case let a as ChangeTextValueAction: return changeTextValue(newText: a.newText)
		case _ as CompletionAction: return completion()
		case let a as CustomDescriptorAction: return a.descriptor
		case _ as ErrorAction: return error()
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

class RxStateTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testInitialState() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		XCTAssertEqual(store.stateValue.state.text, "Initial value")
		XCTAssertNotNil(store.stateValue.setBy as? RxInitialStateAction)
		
		XCTAssertEqual(store.stateStack.count, 1)
		XCTAssertEqual(store.stateStack.peek()?.state.text, "Initial value")
		XCTAssertTrue(store.stateStack.peek()?.setBy is RxInitialStateAction)
	}
	
	func testReturnCurrentStateOnSubscribe() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should return initial state")
		
		_ = store.state.subscribe(onNext: { next in
			guard next.setBy is RxInitialStateAction else { return }
			guard next.state.text == "Initial value" else { return }
			completeExpectation.fulfill()
		})
		
		waitForExpectations(timeout: 1, handler: nil)
	}
	
	func testPerformAction() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should change state")
		
		_ = store.state.subscribe(onNext: { next in
			guard next.setBy is ChangeTextValueAction else { return }
			XCTAssertEqual(next.state.text, "New text")
			completeExpectation.fulfill()
		})
		
		store.dispatch(ChangeTextValueAction(newText: "New text"))
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(store.stateStack.count, 2)
		XCTAssertEqual(store.stateStack.peek()?.state.text, "New text")
		XCTAssertTrue(store.stateStack.peek()?.setBy is ChangeTextValueAction)
	}
	
	func testTrimHistory() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 10)
		let completeExpectation = expectation(description: "Should change state")
		
		let counter = 10
		
		var newStateCounter = 0
		_ = store.state.skip(1).subscribe(onNext: { _ in
			newStateCounter += 1
			if newStateCounter == 10 {
				completeExpectation.fulfill()
			}
		})
		
		for i in 0...counter {
			store.dispatch(ChangeTextValueAction(newText: "New text \(i)"))
		}
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(store.stateStack.count, 10)
		XCTAssertEqual(store.stateStack.pop()?.state.text, "New text 10")
		XCTAssertEqual(store.stateStack.first()?.state.text, "New text 1")
	}
	
	
	func testPorformActionAndPropagateError() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let errorExpectation = expectation(description: "Should rise error")
		
		_ = store.errors.subscribe(onNext: { e in
			XCTAssertEqual(TestError.someError, e.error as! TestError)
			XCTAssertTrue(e.action is ErrorAction)
			XCTAssertEqual("New text before error", (e.state as? TestState)?.text)
			if case TestError.someError = e.error {
				errorExpectation.fulfill()
			}
		})
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text before error"))
		store.dispatch(ErrorAction())
		
		waitForExpectations(timeout: 1, handler: nil)
	}
	
	func testContinueWorkAfterErrorAction() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		var changeTextValueActionCount = 0
		_ = store.state.filter { $0.setBy is ChangeTextValueAction }.subscribe(onNext: { next in
			changeTextValueActionCount += 1
		})
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text 3"))
		store.dispatch(ErrorAction())
		store.dispatch(ChangeTextValueAction(newText: "New text 4"))
		store.dispatch(ChangeTextValueAction(newText: "Last text change"))
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(5, changeTextValueActionCount, "Should change text five times")
		XCTAssertEqual("Completed", store.stateValue.state.text)
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "New text 1",
		                                      "New text 2",
		                                      "New text 3",
		                                      "New text 4",
		                                      "Last text change",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	
	func testSerialActionDispatch() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		for i in 1...11 {
			let after = (i % 2 == 0) ? 0.15 : 0
			let action: RxActionType = {
				if i == 11 {
					return CompletionAction()
				} else if i % 3 == 0 {
					let descriptor = Observable<RxStateType>.error(TestError.someError).delaySubscription(after, scheduler: delayScheduler)
					return CustomDescriptorAction(scheduler: delayScheduler, descriptor: descriptor)
				} else {
					let descriptor = Observable<RxStateType>.just(TestState(text: "Action \(i) executed")).delaySubscription(after, scheduler: delayScheduler)
					return CustomDescriptorAction(scheduler: delayScheduler, descriptor: descriptor)
				}
			}()
			
			store.dispatch(action)
		}
		
		waitForExpectations(timeout: 5, handler: nil)
		
		let expectedStateHistoryTextValues = ["Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Action 7 executed",
		                                      "Action 8 executed",
		                                      "Action 10 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatch_1() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.01) { store.dispatch(ChangeTextValueAction(newText: "New text 2")) }
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.1) { store.dispatch(ChangeTextValueAction(newText: "New text 3")) }
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.30) { store.dispatch(CompletionAction()) }
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual("Completed", store.stateValue.state.text)
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "New text 1",
		                                      "New text 2",
		                                      "New text 3",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInCorrectScheduler_1() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action1Scheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		
		let descriptor: Observable<RxStateType> = {
			return Observable.create { observer in
				XCTAssertTrue(!Thread.isMainThread)
				observer.onNext(TestState(text: "Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}()
		let action1 = CustomDescriptorAction(scheduler: action1Scheduler, descriptor: descriptor)
		store.dispatch(action1)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Completed"]
		
		XCTAssertEqual(1, action1Scheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInCorrectScheduler_2() {
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let actionScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		
		let action1 = CustomDescriptorAction(scheduler: actionScheduler, descriptor: .just(TestState(text: "Action 1 executed")))
		let action2 = CustomDescriptorAction(scheduler: actionScheduler, descriptor: .just(TestState(text: "Action 2 executed")))
		let action3 = CustomDescriptorAction(scheduler: actionScheduler, descriptor: .just(TestState(text: "Action 3 executed")))
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Completed"]
		
		XCTAssertEqual(3, actionScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInDefaultScheduler() {
		let storeScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8, scheduler: storeScheduler)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: .just(TestState(text: "Action 1 executed")))
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: .just(TestState(text: "Action 2 executed")))
		
		let action3Scheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let action3 = CustomDescriptorAction(scheduler: action3Scheduler, descriptor: .just(TestState(text: "Action 3 executed")))
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Completed"]
		
		XCTAssertEqual(3, storeScheduler.scheduleCounter)
		XCTAssertEqual(1, action3Scheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInMainScheduer() {
		let storeScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8, scheduler: storeScheduler)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let descriptor: Observable<RxStateType> = {
			return Observable.create { observer in
				XCTAssertTrue(Thread.isMainThread)
				observer.onNext(TestState(text: "Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}()
		let action1 = CustomDescriptorAction(scheduler: MainScheduler.instance, descriptor: descriptor)
		
		store.dispatch(action1)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Completed"]
		
		XCTAssertEqual(1, storeScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
}
