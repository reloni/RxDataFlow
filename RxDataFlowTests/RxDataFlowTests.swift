//
//  RxDataFlow.swift
//  RxStateTests
//
//  Created by Anton Efimenko on 02.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import XCTest
import RxSwift
@testable import RxDataFlow
//
//enum TestEnum {
//	case some(DeinitObject)
//}
//
//class DeinitTests: XCTestCase {
//	func testDeinit() {
//		let input = PublishSubject<TestEnum>()
//		let output = PublishSubject<TestEnum>()
//
//		_ = input.asObservable()
//			.map { Observable.just($0) }
//			.merge(maxConcurrent: 1)
//			.observeOn(SerialDispatchQueueScheduler(qos: .utility))
//			.do(onNext: { v in print(v) })
//			.subscribe(onNext: { obj in print(obj) })
//
//		_ = output.observeOn(SerialDispatchQueueScheduler(qos: .utility)).do(onNext: { print("output: \($0)") }).subscribe()
//
//		(0...10).forEach { value in input.onNext(TestEnum.some(DeinitObject({ print("Object \(value) deinited") }))) }
//
//		sleep(3)
//	}
//}

class RxDataFlowTests: XCTestCase {
    let timeout: TimeInterval = 10
    
	func testObjectPassedToControllerDeinited() {
		let store: TestFlowController! = TestFlowController(reducer: testStoreReducer,
                                                            initialState: TestState(text: "Initial value"))
		
		let deinitExpectation = expectation(description: "Object should be deinited")
		
//		_ = store.state.subscribe(onNext: { print($0.setBy) })
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		store.dispatch(EnumAction.deinitObject(DeinitObject({ deinitExpectation.fulfill() })))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		
		let deinitResult = XCTWaiter().wait(for: [deinitExpectation], timeout: timeout)
		XCTAssertEqual(deinitResult, .completed)
	}
	
	func testObjectPassedToControllerStoredAndNotDeinited() {
		let store: TestFlowController! = TestFlowController(reducer: testStoreReducer,
															initialState: TestState(text: "Initial value"))
		
		let deinitExpectation = expectation(description: "Object should be deinited")
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		store.dispatch(EnumAction.deinitObject(DeinitObject({ deinitExpectation.fulfill() })))
		
		let deinitResult = XCTWaiter().wait(for: [deinitExpectation], timeout: timeout)
		XCTAssertEqual(deinitResult, .timedOut)
		XCTAssertEqual(store.currentState.state.text, "Deinit object")
	}
	
	/// Test FlowController deinit if there is no actions to dispatch
	func testDeinit() {
		var store: TestFlowController! = TestFlowController(reducer: testStoreReducer,
		                               initialState: TestState(text: "Initial value"))
		
		let deinitExpectation = expectation(description: "Should deinit")
		
		store.onDeinit = { _ in
			deinitExpectation.fulfill()
		}
		
		let completeExpectation = expectation(description: "Should not fulfill this expectation")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { _ in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (1)")).delay(0.1, scheduler: delayScheduler), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (2)")).delay(0.3, scheduler: delayScheduler), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (3)")).delay(0.7, scheduler: delayScheduler), isSerial: true)
		let action4 = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed (4)")).delay(1.0, scheduler: delayScheduler), isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(action4)
		store.dispatch(CompletionAction())
		
		let completeResult = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		
		store = nil
		
		let deinitResult = XCTWaiter().wait(for: [deinitExpectation], timeout: timeout)
		
		
		XCTAssertEqual(deinitResult, .completed)
		XCTAssertEqual(completeResult, .completed)
		XCTAssertNotNil(stateHistory)
		XCTAssertEqual(6, stateHistory.count)
	}
	
	/// Test FlowController stop action execution on deinit
	func testDeinit_2() {
		var store: TestFlowController! = TestFlowController(reducer: testStoreReducer,
		                                                    initialState: TestState(text: "Initial value"))
		
		let deinitExpectation = expectation(description: "Should deinit")
		
		store.onDeinit = { _ in
			deinitExpectation.fulfill()
		}
		
		let completeExpectation = expectation(description: "Should not fulfill this expectation")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { _ in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		for i in 0..<1000 {
			let action = CustomDescriptorAction(scheduler: nil, descriptor: Observable.just(testStateDescriptor(text: "Action executed \(i)")).delay(0.001, scheduler: delayScheduler), isSerial: true)
			store.dispatch(action)
		}
		
		store.dispatch(CompletionAction())
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			store = nil
		}
		
		let completeResult = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		let deinitResult = XCTWaiter().wait(for: [deinitExpectation], timeout: timeout)
		
		
		XCTAssertEqual(deinitResult, .completed)
		XCTAssertEqual(completeResult, .timedOut)
		XCTAssertNotNil(stateHistory)
		XCTAssertTrue(stateHistory.count < 1000)
	}
	
	func testInitialState() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		XCTAssertEqual(store.currentState.state.text, "Initial value")
		XCTAssertNotNil(store.currentState.setBy as? RxInitializationAction)
	}
	
	func testReturnCurrentStateOnSubscribe() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should return initial state")
		
		_ = store.state.subscribe(onNext: { next in
			guard next.setBy is RxInitializationAction else { return }
			guard next.state.text == "Initial value" else { return }
			completeExpectation.fulfill()
		})
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
	}
	
	func testDispatchActionAfterInitialization() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 dispatchAction: ChangeTextValueAction(newText: "Change on init"))
		
		let completeExpectation = expectation(description: "Should dispatch action after initialization")
		
		_ = store.state.subscribe(onNext: { next in
			guard next.setBy is ChangeTextValueAction else { return }
			completeExpectation.fulfill()
		})
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		
		XCTAssertEqual(result, .completed)
	}
	
	func testPerformAction() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should change state")
		
		_ = store.state.subscribe(onNext: { next in
			guard next.setBy is ChangeTextValueAction else { return }
			XCTAssertEqual(next.state.text, "New text")
			completeExpectation.fulfill()
		})
		
		store.dispatch(ChangeTextValueAction(newText: "New text"))
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		
		XCTAssertEqual(result, .completed)
	}
	
	func testPorformActionAndPropagateError() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let errorExpectation = expectation(description: "Should rise error")
		
		_ = store.errors.subscribe(onNext: { e in
			XCTAssertEqual(TestError.someError, e.error as! TestError)
			XCTAssertTrue(e.action is ErrorAction)
			XCTAssertEqual("New text before error", e.state.text)
			if case TestError.someError = e.error {
				errorExpectation.fulfill()
			}
		})
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text before error"))
		store.dispatch(ErrorAction())
		
		let result = XCTWaiter().wait(for: [errorExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
	}
	
	func testContinueWorkAfterErrorAction() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		var changeTextValueActionCount = 0
		_ = store.state.filter { $0.setBy is ChangeTextValueAction }.subscribe(onNext: { next in
			changeTextValueActionCount += 1
		})
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		store.dispatch(ChangeTextValueAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueAction(newText: "New text 3"))
		store.dispatch(ErrorAction())
		store.dispatch(ChangeTextValueAction(newText: "New text 4"))
		store.dispatch(ChangeTextValueAction(newText: "Last text change"))
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		
		XCTAssertEqual(result, .completed)
		XCTAssertEqual(5, changeTextValueActionCount, "Should change text five times")
		XCTAssertEqual("Completed", store.currentState.state.text)
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "New text 1",
		                                      "New text 2",
		                                      "New text 3",
		                                      "New text 4",
		                                      "Last text change",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	
	func testSerialActionDispatch_1() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		for i in 1...11 {
			let after = (i % 2 == 0) ? 0.15 : 0
			let action: RxActionType = {
				if i == 11 {
					return CompletionAction()
				} else if i % 3 == 0 {
					let descriptor = Observable<RxStateMutator<TestState>>.error(TestError.someError).delaySubscription(after, scheduler: delayScheduler)
					return CustomDescriptorAction(scheduler: delayScheduler, descriptor: descriptor, isSerial: true)
				} else {
					let descriptor = Observable<RxStateMutator<TestState>>.just(testStateDescriptor(text: "Action \(i) executed")).delaySubscription(after, scheduler: delayScheduler)
					return CustomDescriptorAction(scheduler: delayScheduler, descriptor: descriptor, isSerial: true)
				}
			}()
			
			store.dispatch(action)
		}
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 5)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Action 7 executed",
		                                      "Action 8 executed",
		                                      "Action 10 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testSerialActionDispatch_2() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
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
				XCTAssertEqual(store.currentState.state.text, "Action 2 executed")
				DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.4) {
					XCTAssertEqual(store.currentState.state.text, "Action 2 executed")
					observer.onNext(testStateDescriptor(text: "Action 3 executed"))
					observer.onCompleted()
				}
				return Disposables.create()
			}
		}()
		
		store.dispatch(ChangeTextValueAction(newText: "Action 1 executed"))
		store.dispatch(CustomDescriptorAction(scheduler: nil, descriptor: descriptor1, isSerial: true))
		store.dispatch(CustomDescriptorAction(scheduler: nil, descriptor: descriptor2, isSerial: true))
		store.dispatch(ChangeTextValueAction(newText: "Action 4 executed"))
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: 5)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Action 4 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testDispatch_1() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		store.dispatch(ChangeTextValueAction(newText: "New text 1"))
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.01) { store.dispatch(ChangeTextValueAction(newText: "New text 2")) }
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.1) { store.dispatch(ChangeTextValueAction(newText: "New text 3")) }
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.30) { store.dispatch(CompletionAction()) }
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		XCTAssertEqual("Completed", store.currentState.state.text)
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "New text 1",
		                                      "New text 2",
		                                      "New text 3",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testDispatchInCorrectScheduler_1() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let action1Scheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		
		let descriptor: Observable<RxStateMutator<TestState>> = {
			return Observable.create { observer in
				XCTAssertTrue(!Thread.isMainThread)
				observer.onNext(testStateDescriptor(text: "Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}()
		let action1 = CustomDescriptorAction(scheduler: action1Scheduler, descriptor: descriptor, isSerial: true)
		store.dispatch(action1)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Completed"]
		
		XCTAssertEqual(1, action1Scheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testDispatchInCorrectScheduler_2() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let actionScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		
		let action1 = CustomDescriptorAction(scheduler: actionScheduler, descriptor: .just(testStateDescriptor(text: "Action 1 executed")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: actionScheduler, descriptor: .just(testStateDescriptor(text: "Action 2 executed")), isSerial: true)
		let action3 = CustomDescriptorAction(scheduler: actionScheduler, descriptor: .just(testStateDescriptor(text: "Action 3 executed")), isSerial: true)
		
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
		                                      "Completed"]
		
		XCTAssertEqual(3, actionScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testDispatchInDefaultScheduler() {
		let storeScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: storeScheduler)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.observeOn(SerialDispatchQueueScheduler(qos: .background)).filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: .just(testStateDescriptor(text: "Action 1 executed")), isSerial: true)
		let action2 = CustomDescriptorAction(scheduler: nil, descriptor: .just(testStateDescriptor(text: "Action 2 executed")), isSerial: true)
		
		let action3Scheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let action3 = CustomDescriptorAction(scheduler: action3Scheduler, descriptor: .just(testStateDescriptor(text: "Action 3 executed")), isSerial: true)
		
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
		                                      "Completed"]
		
		XCTAssertEqual(3, storeScheduler.scheduleCounter)
		XCTAssertEqual(1, action3Scheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testDispatchInMainScheduer() {
		let storeScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"),
		                                 scheduler: storeScheduler)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let descriptor: Observable<RxStateMutator<TestState>> = {
			return Observable.create { observer in
				XCTAssertTrue(Thread.isMainThread)
				observer.onNext(testStateDescriptor(text: "Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}()
		let action1 = CustomDescriptorAction(scheduler: MainScheduler.instance, descriptor: descriptor, isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Completed"]
		
		XCTAssertEqual(1, storeScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testMultipleStateChangesInOneDescriptor() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let descriptor: Observable<RxStateMutator<TestState>> = {
			return Observable.create { observer in
				observer.onNext(testStateDescriptor(text: "Action executed (1)"))
				observer.onNext(testStateDescriptor(text: "Action executed (2)"))
				
				DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 1.5) {
					observer.onNext(testStateDescriptor(text: "Action executed (3)"))
					observer.onNext(testStateDescriptor(text: "Action executed (4)"))
					observer.onCompleted()
				}
				
				return Disposables.create()
			}
		}()
		let action1 = CustomDescriptorAction(scheduler: nil, descriptor: descriptor, isSerial: true)
		
		store.dispatch(action1)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action executed (1)",
		                                      "Action executed (2)",
		                                      "Action executed (3)",
		                                      "Action executed (4)",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
	
	func testDispatchReducerHandleFunctionInCorrectScheduler() {
		let store = RxDataFlowController(reducer: testStoreReducer,
		                                 initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		var stateHistory = [String]()
		_ = store.state.do(onNext: { stateHistory.append($0.state.text) }).subscribe()
		
		let action1Descriptor: Observable<RxStateMutator<TestState>> = {
			return Observable.create { observer in
				XCTAssertTrue(Thread.isMainThread)
				observer.onNext(testStateDescriptor(text: "Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}()
		
		let action1 = EnumAction.inMainScheduler(action1Descriptor)
		
		let action2Scheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let action2 = EnumAction.inCustomScheduler(action2Scheduler, .just(testStateDescriptor(text: "Action 2 executed")))
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(CompletionAction())
		
		let result = XCTWaiter().wait(for: [completeExpectation], timeout: timeout)
		XCTAssertEqual(result, .completed)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Completed"]
		
		XCTAssertEqual(1, action2Scheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, stateHistory)
	}
    
    func testStoreAndPassCorrectState() {
        let store = RxDataFlowController(reducer: testStoreReducer,
                                         initialState: TestState(text: "Initial value"))
        let completeExpectation = expectation(description: "Should perform all non-error actions")
        
        _ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
            completeExpectation.fulfill()
        })

        store.dispatch(CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 1", stateText: "Initial value"))
        store.dispatch(CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 2", stateText: "Value 1"))
        store.dispatch(CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 3", stateText: "Value 2"))
        store.dispatch(CompareStateAction(isSerial: true, scheduler: nil, newText: "Value 4", stateText: "Value 3"))
        store.dispatch(CompletionAction())
        
        let result = XCTWaiter().wait(for: [completeExpectation], timeout: 100)
        XCTAssertEqual(result, .completed)
        
        XCTAssertEqual("Completed", store.currentState.state.text)
    }
}
