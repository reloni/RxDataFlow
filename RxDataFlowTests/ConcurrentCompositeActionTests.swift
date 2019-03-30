//
//  ConcurrentCompositeActionTests.swift
//  RxDataFlow
//
//  Created by Anton Efimenko on 16.05.17.
//  Copyright © 2017 Anton Efimenko. All rights reserved.
//

import XCTest
@testable import RxDataFlow
import RxSwift

class ConcurrentCompositeActionTests: XCTestCase {
	let timeout: TimeInterval = 10
    
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testSerialExecutionOfConcurrentCompositeAction() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")).delay(0.9, scheduler: delayScheduler), isSerial: true)
		let action3 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (3)")).delay(0.002, scheduler: delayScheduler), isSerial: true)
		let action4 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (4)")).delay(0.001, scheduler: delayScheduler), isSerial: true)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")).delay(0.2, scheduler: delayScheduler), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, action4, action5, isSerial: false))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (6)",
		                                      "Action executed (2)",
		                                      "Action executed (3)",
		                                      "Action executed (4)",
		                                      "Action executed (5)",
		                                      "Completed"]
		
		XCTAssertEqual(8, serialScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testMultipleSerialCompositeActions() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")).delay(0.2, scheduler: delayScheduler), isSerial: true)
		let action3 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (3)")).delay(0.002, scheduler: delayScheduler), isSerial: true)
		let action4 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (4)")).delay(0.001, scheduler: delayScheduler), isSerial: true)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")).delay(0.3, scheduler: delayScheduler), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, isSerial: false))
		store.dispatch(RxCompositeAction(action4, action5, isSerial: false))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (6)",
		                                      "Action executed (4)",
		                                      "Action executed (2)",
		                                      "Action executed (3)",
		                                      "Action executed (5)",
		                                      "Completed"]
		
		XCTAssertEqual(9, serialScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
}
