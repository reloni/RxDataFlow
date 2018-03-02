//
//  CompositeActions.swift
//  RxDataFlow
//
//  Created by Anton Efimenko on 26.02.17.
//  Copyright © 2017 Anton Efimenko. All rights reserved.
//

import XCTest
import RxSwift
@testable import RxDataFlow

class CompositeActions: XCTestCase {
    let timeout: TimeInterval = 3
    
	func testCompositeAction() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let action = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                         ChangeTextValueAction(newText: "Action 2 executed"),
		                                         ChangeTextValueAction(newText: "Action 3 executed"),
		                                         ChangeTextValueAction(newText: "Action 4 executed")])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Completed"]

		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testCorrectSetByAction() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))

		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})

		let changeTextValueActionExpectation = expectation(description: "Should perform ChangeTextValueAction with correct setBy")
		let customDescriptorActionExpectation = expectation(description: "Should perform CustomDescriptorAction with correct setBy")
		_ = store.state.subscribe(onNext: { next in
			if next.setBy is ChangeTextValueAction {
				changeTextValueActionExpectation.fulfill()
			} else if next.setBy is CustomDescriptorAction {
				customDescriptorActionExpectation.fulfill()
			}
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()

		let descriptor = testStateDescriptor(text: "Action 2 executed")
		let action = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                         CustomDescriptorAction(scheduler: nil,
		                                                                descriptor: .just(descriptor),
		                                                                isSerial: true)])
		store.dispatch(action)
		store.dispatch(CompletionAction())

		let result = XCTWaiter().wait(for: [changeTextValueActionExpectation, customDescriptorActionExpectation, completeExpectation], timeout: timeout, enforceOrder: true)
		XCTAssertEqual(result, .completed)

		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Completed"]

		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
		XCTAssertTrue(store.currentState.setBy is CompletionAction)
	}

	func testCompositeActionStopIfErrorOccurred() {

		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		let errorExpectation = expectation(description: "Should throw error")

		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})

		_ = store.errors.subscribe(onNext: { error in
			XCTAssertTrue(error.action is ErrorAction)
			XCTAssertTrue((error.error as? TestError) == TestError.someError)
			errorExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()

		let action = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                         ChangeTextValueAction(newText: "Action 2 executed"),
		                                         ErrorAction(),
		                                         ChangeTextValueAction(newText: "Action 3 executed"),
		                                         ChangeTextValueAction(newText: "Action 4 executed")])
		store.dispatch(action)
		store.dispatch(CompletionAction())

		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		let errorResult = XCTWaiter.wait(for: [errorExpectation], timeout: timeout)

		XCTAssertEqual(result, .completed)
		XCTAssertEqual(errorResult, .completed)

		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Completed"]

		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}

	func testMultipleCompositeActions() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))

		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()

		let action1 = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                          ChangeTextValueAction(newText: "Action 2 executed"),
		                                          ChangeTextValueAction(newText: "Action 3 executed"),
		                                          ChangeTextValueAction(newText: "Action 4 executed")])
		let action2 = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 5 executed"),
		                                          ChangeTextValueAction(newText: "Action 6 executed"),
		                                          ErrorAction(),
		                                          ChangeTextValueAction(newText: "Action 7 executed"),
		                                          ChangeTextValueAction(newText: "Action 8 executed")])
		let action3 = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 9 executed"),
		                                          ChangeTextValueAction(newText: "Action 10 executed"),
		                                          ChangeTextValueAction(newText: "Action 11 executed"),
		                                          ChangeTextValueAction(newText: "Action 12 executed")])
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(CompletionAction())

		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)

		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Action 6 executed",
		                                      "Action 9 executed",
		                                      "Action 10 executed",
		                                      "Action 11 executed",
		                                      "Action 12 executed",
		                                      "Completed"]

		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}

	func testInvokeChildActionsInCorrectScheduler() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)))

		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()

		let topScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let scheduler1 = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let scheduler2 = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let scheduler3 = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))

		let action1 = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed", scheduler: scheduler1),
		                                          ChangeTextValueAction(newText: "Action 2 executed", scheduler: scheduler2),
		                                          EnumAction.inCustomScheduler(scheduler3, .just(testStateDescriptor(text: "Action 3 executed"))),
		                                          ChangeTextValueAction(newText: "Action 4 executed"),
		                                          EnumAction.inMainScheduler(.just(testStateDescriptor(text: "Action 5 executed")))],
		                                scheduler: topScheduler)
		store.dispatch(action1)

		let action2 = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 6 executed", scheduler: nil),
		                                          ChangeTextValueAction(newText: "Action 7 executed", scheduler: nil),
		                                          EnumAction.inCustomScheduler(scheduler3, .just(testStateDescriptor(text: "Action 8 executed"))),
		                                          ChangeTextValueAction(newText: "Action 9 executed"),
		                                          EnumAction.inMainScheduler(.just(testStateDescriptor(text: "Action 10 executed")))],
		                                scheduler: nil)
		store.dispatch(action2)

		store.dispatch(CompletionAction())

		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)

		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Action 6 executed",
		                                      "Action 7 executed",
		                                      "Action 8 executed",
		                                      "Action 9 executed",
		                                      "Action 10 executed",
		                                      "Completed"]

		XCTAssertEqual(1, topScheduler.scheduleCounter)
		XCTAssertEqual(1, scheduler1.scheduleCounter)
		XCTAssertEqual(1, scheduler2.scheduleCounter)
		XCTAssertEqual(2, scheduler3.scheduleCounter)
		XCTAssertEqual(4, (store.scheduler as! TestScheduler).scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}

	func testInvokeChildActionsInCorrectOrder() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)))

		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})

		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()

		let descriptor1: Observable<RxStateMutator<TestState>> = {
			return Observable.create { observer in
				XCTAssertEqual(store.currentState.state.text, "Action 1 executed")
				DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 1.0) {
					XCTAssertEqual(store.currentState.state.text, "Action 1 executed")
					observer.onNext(testStateDescriptor(text: "Action 2 executed"))
					observer.onCompleted()
				}
				return Disposables.create()
			}
		}()

		let descriptor2: Observable<RxStateMutator<TestState>> = {
			return Observable.create { observer in
				XCTAssertEqual(store.currentState.state.text, "Action 5 executed")
				DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.2) {
					XCTAssertEqual(store.currentState.state.text, "Action 5 executed")
					observer.onNext(testStateDescriptor(text: "Action 6 executed"))
					observer.onCompleted()
				}
				return Disposables.create()
			}
		}()

		let action = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed", scheduler: nil),
		                                         CustomDescriptorAction(scheduler: nil, descriptor: descriptor1, isSerial: true),
		                                         ChangeTextValueAction(newText: "Action 3 executed", scheduler: nil),
		                                         ChangeTextValueAction(newText: "Action 4 executed"),
		                                         EnumAction.inMainScheduler(.just(testStateDescriptor(text: "Action 5 executed"))),
		                                         CustomDescriptorAction(scheduler: nil, descriptor: descriptor2, isSerial: true)])
		store.dispatch(action)
		store.dispatch(CompletionAction())

		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)

		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Action 6 executed",
		                                      "Completed"]

		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}

	func testFallbackAction() {
		let serialScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: serialScheduler)

		let completeExpectation = expectation(description: "Should perform all non-error actions")

		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})

		var errorCounter = 0
		_ = store.errors.subscribe(onNext: {
			if case TestError.someError = $0.error { errorCounter += 1 }
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()

		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)

		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (1)")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (2)")).delay(0.2, scheduler: delayScheduler), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (3)")).delay(0.002, scheduler: delayScheduler), isSerial: true)
		let action4 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (4)")).delay(0.001, scheduler: delayScheduler), isSerial: true)
		let action5 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (5)")).delay(0.3, scheduler: delayScheduler), isSerial: true)
		let action6 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (6)")), isSerial: true)

		let fallback1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Fallback 1 executed")), isSerial: true)
		let fallback2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Fallback 2 executed")), isSerial: true)

		store.dispatch(action1)
		store.dispatch(RxCompositeAction(action2, ErrorAction(), action3, fallbackAction: fallback1, isSerial: true))
		store.dispatch(RxCompositeAction(action4, ErrorAction(), action5, fallbackAction: fallback2, isSerial: true))
		store.dispatch(action6)
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
			store.dispatch(CompletionAction())
		}

		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)

		XCTAssertEqual(result, .completed)

		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (4)",
		                                      "Action executed (6)",
		                                      "Fallback 1 executed",
		                                      "Fallback 2 executed",
		                                      "Completed"]

		XCTAssertEqual(9, serialScheduler.scheduleCounter)
		XCTAssertEqual(2, errorCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testStoreAndPassCorrectState_serial() {
		let store = RxDataFlowController(reducer: testStoreReducer,
										 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action = RxCompositeAction(actions: [CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 1", stateText: "Initial value"),
												 CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 2", stateText: "Value 1"),
												 CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 3", stateText: "Value 2"),
												 CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 4", stateText: "Value 3"),
												 CompletionAction()],
									   isSerial: true)
		
		store.dispatch(action)
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 100)
		XCTAssertEqual(result, .completed)
		
		XCTAssertEqual("Completed", store.currentState.state.text)
	}
	
	func testStoreAndPassCorrectState_notSerial() {
		let store = RxDataFlowController(reducer: testStoreReducer,
										 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action = RxCompositeAction(actions: [CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 1", stateText: "Initial value"),
												 CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 2", stateText: "Value 1"),
												 CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 3", stateText: "Value 2"),
												 CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 4", stateText: "Value 3"),
												 CompletionAction()],
									   isSerial: false)
		
		store.dispatch(action)
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 100)
		XCTAssertEqual(result, .completed)
		
		XCTAssertEqual("Completed", store.currentState.state.text)
	}
}
