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
		                                 initialState: TestState(text: "Initial value"))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action = CompositeAction(scheduler: nil, actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                                       ChangeTextValueAction(newText: "Action 2 executed"),
		                                                       ChangeTextValueAction(newText: "Action 3 executed"),
		                                                       ChangeTextValueAction(newText: "Action 4 executed")])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testCompositeActionStopIfErrorOccurred() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action = CompositeAction(scheduler: nil, actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                                       ChangeTextValueAction(newText: "Action 2 executed"),
		                                                       ErrorAction(),
		                                                       ChangeTextValueAction(newText: "Action 3 executed"),
		                                                       ChangeTextValueAction(newText: "Action 4 executed")])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testMultipleCompositeActions() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action1 = CompositeAction(scheduler: nil, actions: [ChangeTextValueAction(newText: "Action 1 executed"),
		                                                        ChangeTextValueAction(newText: "Action 2 executed"),
		                                                        ChangeTextValueAction(newText: "Action 3 executed"),
		                                                        ChangeTextValueAction(newText: "Action 4 executed")])
		let action2 = CompositeAction(scheduler: nil, actions: [ChangeTextValueAction(newText: "Action 5 executed"),
		                                                        ChangeTextValueAction(newText: "Action 6 executed"),
		                                                        ErrorAction(),
		                                                        ChangeTextValueAction(newText: "Action 7 executed"),
		                                                        ChangeTextValueAction(newText: "Action 8 executed")])
		let action3 = CompositeAction(scheduler: nil, actions: [ChangeTextValueAction(newText: "Action 9 executed"),
		                                                        ChangeTextValueAction(newText: "Action 10 executed"),
		                                                        ChangeTextValueAction(newText: "Action 11 executed"),
		                                                        ChangeTextValueAction(newText: "Action 12 executed")])
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
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
		                                 scheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let topScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let scheduler1 = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let scheduler2 = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let scheduler3 = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let action = CompositeAction(scheduler: topScheduler, actions: [ChangeTextValueAction(newText: "Action 1 executed", scheduler: scheduler1),
		                                                       ChangeTextValueAction(newText: "Action 2 executed", scheduler: scheduler2),
		                                                       EnumAction.inCustomScheduler(scheduler3, .just((TestState(text: "Action 3 executed")))),
		                                                       ChangeTextValueAction(newText: "Action 4 executed"),
		                                                       EnumAction.inMainScheduler(.just((TestState(text: "Action 5 executed"))))])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Completed"]
		
		// nothing should be invoked in top level scheduler, specified by CompositeAction,
		// because FlowController will use schedulers specified in child tasks
		XCTAssertEqual(0, topScheduler.scheduleCounter)
		XCTAssertEqual(1, scheduler1.scheduleCounter)
		XCTAssertEqual(1, scheduler2.scheduleCounter)
		XCTAssertEqual(1, scheduler3.scheduleCounter)
		XCTAssertEqual(2, (store.scheduler as! TestScheduler).scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testInvokeChildActionsInCorrectOrder() {
		let store = RxDataFlowController(reducer: TestStoreReducer(),
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility)))
		
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		
		let descriptor1: Observable<RxStateType> = {
			return Observable.create { observer in
				DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 1.0) {
					observer.onNext(TestState(text: "Action 2 executed"))
					observer.onCompleted()
				}
				return Disposables.create()
			}
		}()
		
		let descriptor2: Observable<RxStateType> = {
			return Observable.create { observer in
				
				DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.2) {
					observer.onNext(TestState(text: "Action 6 executed"))
					observer.onCompleted()
				}
				return Disposables.create()
			}
		}()
		
		let action = CompositeAction(scheduler: nil, actions: [ChangeTextValueAction(newText: "Action 1 executed", scheduler: nil),
		                                                       CustomDescriptorAction(scheduler: nil, descriptor: descriptor1),
		                                                       ChangeTextValueAction(newText: "Action 3 executed", scheduler: nil),
		                                                       ChangeTextValueAction(newText: "Action 4 executed"),
		                                                       EnumAction.inMainScheduler(.just((TestState(text: "Action 5 executed")))),
		                                                       CustomDescriptorAction(scheduler: nil, descriptor: descriptor2),])
		store.dispatch(action)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 3, handler: nil)
		
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
