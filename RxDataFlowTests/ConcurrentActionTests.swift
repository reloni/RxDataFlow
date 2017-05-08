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
	func testScheduleConcurrentActions() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let concurrentScheduler = TestScheduler(internalScheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 8,
		                                 serialActionScheduler: serialScheduler,
		                                 concurrentActionScheduler: concurrentScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (3)")).delay(0.2, scheduler: delayScheduler), isSerial: false)
		let action4 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (4)")).delay(0.1, scheduler: delayScheduler), isSerial: false)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(action4)
		store.dispatch(action5)
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1.5)
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
		XCTAssertEqual(4, concurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testScheduleConcurrentActions_withOwnScheduler() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let concurrentScheduler = TestScheduler(internalScheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 8,
		                                 serialActionScheduler: serialScheduler,
		                                 concurrentActionScheduler: concurrentScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let actionConcurrentScheduler = TestScheduler(internalScheduler:  ConcurrentDispatchQueueScheduler(qos: .utility))
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: actionConcurrentScheduler,
		                                     descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (3)")).delay(0.2, scheduler: delayScheduler), isSerial: false)
		let action4 = CustomDescriptorAction(scheduler: actionConcurrentScheduler,
		                                     descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (4)")).delay(0.1, scheduler: delayScheduler), isSerial: false)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(action4)
		store.dispatch(action5)
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1.5)
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
		XCTAssertEqual(0, concurrentScheduler.scheduleCounter)
		XCTAssertEqual(4, actionConcurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testScheduleConcurrentCompositeActions_1() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let concurrentScheduler = TestScheduler(internalScheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 8,
		                                 serialActionScheduler: serialScheduler,
		                                 concurrentActionScheduler: concurrentScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (3)")).delay(0.2, scheduler: delayScheduler), isSerial: false)
		let action4 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (4)")).delay(0.1, scheduler: delayScheduler), isSerial: false)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(RxCompositeAction(action1, action2, action3, action4, action5, action6))
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1.5)
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
		XCTAssertEqual(4, concurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testScheduleConcurrentCompositeActions_2() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let concurrentScheduler = TestScheduler(internalScheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 8,
		                                 serialActionScheduler: serialScheduler,
		                                 concurrentActionScheduler: concurrentScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (3)")).delay(0.2, scheduler: delayScheduler), isSerial: false)
		let action4 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (4)")).delay(0.1, scheduler: delayScheduler), isSerial: false)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1.5)
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
		XCTAssertEqual(4, concurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testScheduleConcurrentCompositeActions_3() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let concurrentScheduler = TestScheduler(internalScheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 8,
		                                 serialActionScheduler: serialScheduler,
		                                 concurrentActionScheduler: concurrentScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		let actionConcurrentScheduler = TestScheduler(internalScheduler:  ConcurrentDispatchQueueScheduler(qos: .utility))
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (2)")), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: actionConcurrentScheduler,
		                                     descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (3)")).delay(0.2, scheduler: delayScheduler), isSerial: false)
		let action4 = CustomDescriptorAction(scheduler: actionConcurrentScheduler,
		                                     descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (4)")).delay(0.1, scheduler: delayScheduler), isSerial: false)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (5)")), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1.5)
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
		XCTAssertEqual(0, concurrentScheduler.scheduleCounter)
		XCTAssertEqual(4, actionConcurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testScheduleConcurrentCompositeActions_4() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let concurrentScheduler = TestScheduler(internalScheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 8,
		                                 serialActionScheduler: serialScheduler,
		                                 concurrentActionScheduler: concurrentScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (2)")).delay(0.1, scheduler: delayScheduler), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (3)")).delay(0.002, scheduler: delayScheduler), isSerial: false)
		let action4 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (4)")).delay(0.001, scheduler: delayScheduler), isSerial: false)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (5)")).delay(0.2, scheduler: delayScheduler), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1.5)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (4)",
		                                      "Action executed (3)",
		                                      "Action executed (5)",
		                                      "Action executed (6)",
		                                      "Completed"]
		
		XCTAssertEqual(5, serialScheduler.scheduleCounter)
		XCTAssertEqual(4, concurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testScheduleConcurrentCompositeActions_withConcurrentError_5() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let concurrentScheduler = TestScheduler(internalScheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 8,
		                                 serialActionScheduler: serialScheduler,
		                                 concurrentActionScheduler: concurrentScheduler)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		let errorExpectation = expectation(description: "Should throw error")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		_ = store.errors.subscribe(onNext: { error in
			XCTAssertTrue(error.action is ConcurrentErrorAction)
			XCTAssertTrue((error.error as? TestError) == TestError.someError)
			errorExpectation.fulfill()
		})
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (2)")).delay(0.1, scheduler: delayScheduler), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (3)")).delay(0.002, scheduler: delayScheduler), isSerial: false)
		let action4 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (4)")).delay(0.001, scheduler: delayScheduler), isSerial: false)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (5)")).delay(0.2, scheduler: delayScheduler), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable<RxStateType>.just(TestState(text: "Action executed (6)")), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, action3, ConcurrentErrorAction(), action4, action5))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			store.dispatch(CompletionAction())
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1.5)
		let errorResult = XCTWaiter.wait(for: [errorExpectation], timeout: 1.5)
		
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
		
		XCTAssertEqual(5, serialScheduler.scheduleCounter)
		XCTAssertEqual(6, concurrentScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
}
