//
//  RxStoreTests.swift
//  RxStateTests
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import XCTest
import RxSwift
import RxState

struct TestState : RxStateType {
	let text: String
}

struct ChangeTextValueAction : RxActionType {
	let newText: String
	var work: (RxStateType) -> Observable<RxActionResultType> {
		return { _ in
			Observable.just(RxDefaultActionResult(self.newText))
		}
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
		case _ as CompletionAction: return Observable.just(currentState)
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
		
		_ = store.dispatch(ChangeTextValueAction(newText: "New text")).subscribe()
		
		waitForExpectations(timeout: 1, handler: nil)
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
		_ = store.dispatch(ChangeTextValueAction(newText: "New text 1")).subscribe()
		_ = store.dispatch(ChangeTextValueAction(newText: "New text 2")).subscribe()
		_ = store.dispatch(ChangeTextValueAction(newText: "New text before error")).subscribe()
		_ = store.dispatch(ErrorAction()).subscribe()
		
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
		
		_ = store.dispatch(ChangeTextValueAction(newText: "New text 1")).subscribe()
		_ = store.dispatch(ChangeTextValueAction(newText: "New text 2")).subscribe()
		_ = store.dispatch(ChangeTextValueAction(newText: "New text 3")).subscribe()
		_ = store.dispatch(ErrorAction()).subscribe()
		_ = store.dispatch(ChangeTextValueAction(newText: "New text 4")).subscribe()
		_ = store.dispatch(ChangeTextValueAction(newText: "Last text change")).subscribe()
		_ = store.dispatch(CompletionAction()).subscribe()
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(5, changeTextValueActionCount, "Should change text five times")
	}
}
