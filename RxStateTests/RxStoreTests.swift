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
	var work: () -> Observable<RxActionResultType> {
		return {
			Observable.just(DefaultActionResult(self.newText))
		}
	}
}

struct TestStoreReducer : RxReducerType {
	func handle(_ action: RxActionType, actionResult: RxActionResultType, currentState: RxStateType) -> Observable<RxStateType> {
		switch action {
		case _ as ChangeTextValueAction: return Observable.just(TestState(text: (actionResult as! DefaultActionResult).value))
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
		XCTAssertNotNil(store.stateValue.setBy as? InitialStateAction)
	}
	
	func testReturnCurrentStateOnSubscribe() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should return initial state")
		
		_ = store.state.subscribe(onNext: { next in
			guard next.setBy is InitialStateAction else { return }
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
			guard next.state.text == "New text" else { return }
			completeExpectation.fulfill()
		})
		
		_ = store.dispatch(ChangeTextValueAction(newText: "New text"))
		
		waitForExpectations(timeout: 1, handler: nil)
	}
}
