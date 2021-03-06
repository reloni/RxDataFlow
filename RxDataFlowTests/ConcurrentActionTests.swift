//
//  ConcurrentActionTests.swift
//  RxDataFlow
//
//  Created by Anton Efimenko on 08.05.17.
//  Copyright © 2017 Anton Efimenko. All rights reserved.
//

import XCTest
@testable import RxDataFlow
import RxSwift

class ConcurrentActionTests: XCTestCase {
    let timeout: TimeInterval = 10
    let completionTimeout: TimeInterval = 1
    
	func testScheduleConcurrentActions() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		var stateHistory = [String]()
		_ = store.state
            .do(onNext: { stateHistory.append($0.state.text) })
            .filter { $0.setBy is CompletionAction }
            .do(onNext: { _ in completeExpectation.fulfill() })
            .subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (3)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: false)
		let action4 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (4)")).delay(.milliseconds(100), scheduler: delayScheduler), isSerial: false)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(action4)
		store.dispatch(action5)
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + completionTimeout) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Completed"]
		
		XCTAssertEqual(9, serialScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testScheduleConcurrentActions_withOwnScheduler() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		var stateHistory = [String]()
		_ = store.state
            .do(onNext: { stateHistory.append($0.state.text) })
            .filter { $0.setBy is CompletionAction }
            .do(onNext: { _ in completeExpectation.fulfill() })
            .subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let actionConcurrentScheduler = TestScheduler(internalScheduler:  ConcurrentDispatchQueueScheduler(qos: .utility))
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomObservableAction(scheduler: actionConcurrentScheduler,
		                                     observable: Observable.just(TestState(text: "Action executed (3)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: false)
		let action4 = CustomObservableAction(scheduler: actionConcurrentScheduler,
		                                     observable: Observable.just(TestState(text: "Action executed (4)")).delay(.milliseconds(100), scheduler: delayScheduler), isSerial: false)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(action4)
		store.dispatch(action5)
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + completionTimeout) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Completed"]
		
		XCTAssertEqual(5, serialScheduler.scheduleCounter)
		XCTAssertEqual(4, actionConcurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testScheduleConcurrentCompositeActions_1() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
        
		var stateHistory = [String]()
		_ = store.state
            .do(onNext: { stateHistory.append($0.state.text) })
            .filter { $0.setBy is CompletionAction }
            .do(onNext: { _ in completeExpectation.fulfill() })
            .subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (3)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: false)
		let action4 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (4)")).delay(.milliseconds(100), scheduler: delayScheduler), isSerial: false)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(RxCompositeAction(action1, action2, action3, action4, action5, action6))
        DispatchQueue.main.asyncAfter(deadline: .now() + completionTimeout) {
			store.dispatch(CompletionAction())
        }
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Completed"]
		
		XCTAssertEqual(9, serialScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testScheduleConcurrentCompositeActions_2() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")

		var stateHistory = [String]()
		_ = store.state
            .do(onNext: { stateHistory.append($0.state.text) })
            .filter { $0.setBy is CompletionAction }
            .do(onNext: { _ in completeExpectation.fulfill() })
            .subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (3)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: false)
		let action4 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (4)")).delay(.milliseconds(100), scheduler: delayScheduler), isSerial: false)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + completionTimeout) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Completed"]
		
		XCTAssertEqual(9, serialScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testScheduleConcurrentCompositeActions_3() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		var stateHistory = [String]()
		_ = store.state
            .do(onNext: { stateHistory.append($0.state.text) })
            .filter { $0.setBy is CompletionAction }
            .do(onNext: { _ in completeExpectation.fulfill() })
            .subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		let actionConcurrentScheduler = TestScheduler(internalScheduler:  ConcurrentDispatchQueueScheduler(qos: .utility))
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomObservableAction(scheduler: actionConcurrentScheduler,
		                                     observable: Observable.just(TestState(text: "Action executed (3)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: false)
		let action4 = CustomObservableAction(scheduler: actionConcurrentScheduler,
		                                     observable: Observable.just(TestState(text: "Action executed (4)")).delay(.milliseconds(100), scheduler: delayScheduler), isSerial: false)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + completionTimeout) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Completed"]
		
		XCTAssertEqual(5, serialScheduler.scheduleCounter)
		XCTAssertEqual(4, actionConcurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testScheduleConcurrentCompositeActions_4() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		var stateHistory = [String]()
		_ = store.state
            .do(onNext: { stateHistory.append($0.state.text) })
            .filter { $0.setBy is CompletionAction }
            .do(onNext: { _ in completeExpectation.fulfill() })
            .subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")).delay(.milliseconds(100), scheduler: delayScheduler), isSerial: true)
		let action3 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (3)")).delay(.milliseconds(2), scheduler: delayScheduler), isSerial: false)
		let action4 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (4)")).delay(.milliseconds(1), scheduler: delayScheduler), isSerial: false)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + completionTimeout) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Completed"]
		
		XCTAssertEqual(9, serialScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testScheduleConcurrentCompositeActions_withConcurrentError_5() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		let errorExpectation = expectation(description: "Should throw error")
		
		var stateHistory = [String]()
		_ = store.state
            .do(onNext: { stateHistory.append($0.state.text) })
            .filter { $0.setBy is CompletionAction }
            .do(onNext: { _ in completeExpectation.fulfill() })
            .subscribe()
		
		_ = store.errors.subscribe(onNext: { error in
			XCTAssertTrue(error.action is ConcurrentErrorAction)
			XCTAssertTrue((error.error as? TestError) == TestError.someError)
			errorExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (2)")).delay(.milliseconds(100), scheduler: delayScheduler), isSerial: true)
		let action3 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (3)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: false)
		let action4 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (4)")).delay(.milliseconds(1), scheduler: delayScheduler), isSerial: false)
		let action5 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (5)")).delay(.milliseconds(200), scheduler: delayScheduler), isSerial: true)
		let action6 = CustomObservableAction(scheduler: nil, observable: Observable.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, ConcurrentErrorAction(), action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + completionTimeout) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		let errorResult = XCTWaiter.wait(for: [errorExpectation], timeout: timeout)
		
		XCTAssertEqual(result, .completed)
		XCTAssertEqual(errorResult, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Completed"]
		
		XCTAssertEqual(11, serialScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
}
