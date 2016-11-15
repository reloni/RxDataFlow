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
	var work: () -> Observable<RxActionResultType> {
		return {
			Observable.just(RxDefaultActionResult(self.newText))
		}
	}
}

struct TestStoreReducer : RxReducerType {
	func handle(_ action: RxActionType, actionResult: RxActionResultType, currentState: RxStateType) -> Observable<RxStateType> {
		switch action {
		case _ as ChangeTextValueAction: return Observable.just(TestState(text: (actionResult as! RxDefaultActionResult).value))
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
		
		_ = store.dispatch(ChangeTextValueAction(newText: "New text"))
		
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
}
