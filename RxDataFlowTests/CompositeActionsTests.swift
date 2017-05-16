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
	func testCompositeAction() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 50)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                         ChangeTextValueAction(newText: "Action 2 executed"),
		                                         ChangeTextValueAction(newText: "Action 3 executed"),
		                                         ChangeTextValueAction(newText: "Action 4 executed")])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testCorrectSetByAction() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 50)
		
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
		
		let descriptor = testStateDescriptor(text: "Action 2 executed")
		let action = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                         CustomDescriptorAction(scheduler: nil,
		                                                                descriptor: .just(descriptor),
		                                                                isSerial: true)])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [changeTextValueActionExpectation, customDescriptorActionExpectation, completeExpectation], timeout: 1, enforceOrder: true)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
		XCTAssertTrue(store.currentState.setBy is CompletionAction)
	}
	
	func testCompositeActionStopIfErrorOccurred() {
		
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 50)
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
		
		let action = RxCompositeAction(actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                         ChangeTextValueAction(newText: "Action 2 executed"),
		                                         ErrorAction(),
		                                         ChangeTextValueAction(newText: "Action 3 executed"),
		                                         ChangeTextValueAction(newText: "Action 4 executed")])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1)
		let errorResult = XCTWaiter.wait(for: [errorExpectation], timeout: 1.5)
		
		XCTAssertEqual(result, .completed)
		XCTAssertEqual(errorResult, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testMultipleCompositeActions() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 50)
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
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
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1)
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
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testInvokeChildActionsInCorrectScheduler() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 50,
		                                 serialActionScheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)),
		                                 concurrentActionScheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
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
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 1)
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
		XCTAssertEqual(4, (store.serialActionScheduler as! TestScheduler).scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testInvokeChildActionsInCorrectOrder() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 maxHistoryItems: 50,
		                                 serialActionScheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)),
		                                 concurrentActionScheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		
		let descriptor1: Observable<RxStateMutator> = {
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
		
		let descriptor2: Observable<RxStateMutator> = {
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
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 3)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Action 6 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
}
