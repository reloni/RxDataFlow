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
	let subscriptionDelay: RxTimeInterval
	let scheduler: SchedulerType?
	var work: (RxStateType) -> Observable<RxActionResultType> {
		return { _ in
			let result: Observable<RxActionResultType> = Observable.just(RxDefaultActionResult(self.newText))
			guard let scheduler = self.scheduler else { return result }
			return result.delaySubscription(self.subscriptionDelay, scheduler: scheduler)
		}
	}
}

extension ChangeTextValueAction {
	init(newText: String) {
		self.init(newText: newText, subscriptionDelay: 0, scheduler: nil)
	}
}

struct CompletionAction : RxActionType {
	var work: (RxStateType) -> Observable<RxActionResultType> {
		return { _ in
			Observable.just(RxDefaultActionResult(""))
		}
	}
}

enum TestError : Error {
	case someError
}

struct ErrorAction : RxActionType {
	var work: (RxStateType) -> Observable<RxActionResultType> {
		return { _ in
			Observable.error(TestError.someError)
		}
	}
}

struct TestStoreReducer : RxReducerType {
	func handle(_ action: RxActionType, actionResult: RxActionResultType, currentState: RxStateType) -> Observable<RxStateType> {
		switch action {
		case _ as ChangeTextValueAction: return Observable.just(TestState(text: (actionResult as! RxDefaultActionResult).value))
		case _ as CompletionAction: return Observable.just(TestState(text: "Completed"))
		default: return Observable.empty()
		}
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
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		XCTAssertEqual(store.stateValue.state.text, "Initial value")
		XCTAssertNotNil(store.stateValue.setBy as? RxInitialStateAction)
		
		XCTAssertEqual(store.stateStack.count, 1)
		XCTAssertEqual(store.stateStack.peek()?.state.text, "Initial value")
		XCTAssertTrue(store.stateStack.peek()?.setBy is RxInitialStateAction)
	}
	
	func testReturnCurrentStateOnSubscribe() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should return initial state")
		
		_ = store.state.subscribe(onNext: { next in
			guard next.setBy is RxInitialStateAction else { return }
			guard next.state.text == "Initial value" else { return }
			completeExpectation.fulfill()
		})
		
		waitForExpectations(timeout: 1, handler: nil)
	}
	
	func testPerformAction() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
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
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 10)
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
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
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
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
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
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
	
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		for i in 1...11 {
			let after = (i % 2 == 0) ? 0.05 : 0
			let action: RxActionType = {
				if i == 11 {
					return CompletionAction()
				} else if i % 3 == 0 {
					return RxDefaultAction(work: { _ in
						return Observable.error(TestError.someError).delaySubscription(after, scheduler: delayScheduler)
					})
				} else {
					return ChangeTextValueAction(newText: "Action \(i) executed", subscriptionDelay: after, scheduler: delayScheduler)
				}
			}()
			
			store.dispatch(action)
		}
		
		waitForExpectations(timeout: 3, handler: nil)
		
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
}
