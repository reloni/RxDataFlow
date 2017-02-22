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

struct ChangeTextValueWithCustomDelayAction : RxActionType {
	let newText: String
    var scheduler: ImmediateSchedulerType?
//	let subscriptionDelay: RxTimeInterval
//	let scheduler: SchedulerType?
    /*
	public var work: RxActionWork {
		return RxActionWork { _ -> Observable<RxActionResultType> in
			let result: Observable<RxActionResultType> = Observable.just(RxDefaultActionResult(self.newText))
			guard let scheduler = self.scheduler else { return result }
			return result.delaySubscription(self.subscriptionDelay, scheduler: scheduler)
		}
	}*/
}

func changeTextValueWithCustomDelayDescriptor(newText: String) -> Observable<RxStateType> {
    return .just(TestState(text: newText))
    //let result: Observable<RxActionResultType> = Observable.just(RxDefaultActionResult(newText))
    //return result
    //guard let scheduler = self.scheduler else { return result }
    //return result.delaySubscription(self.subscriptionDelay, scheduler: scheduler)
}

extension ChangeTextValueWithCustomDelayAction {
	init(newText: String) {
		//self.init(newText: newText, subscriptionDelay: 0, scheduler: nil)
        self.init(newText: newText, scheduler: nil)
	}
}

struct ChangeTextValueAction : RxActionType {
    var scheduler: ImmediateSchedulerType?
	//let work: RxActionWork
}

struct CompletionAction : RxActionType {
    var scheduler: ImmediateSchedulerType?
//	public var work: RxActionWork {
//		return RxActionWork { _ in
//			Observable.just(RxDefaultActionResult(""))
//		}
//	}
}

enum TestError : Error {
	case someError
}

struct ErrorAction : RxActionType {
    var scheduler: ImmediateSchedulerType?
//	public var work: RxActionWork {
//		return RxActionWork { _ in
//			Observable.error(TestError.someError)
//		}
//	}
}

struct TestStoreReducer : RxReducerType {
    typealias T = TestState
    func handle<T : RxStateType>(_ action: RxActionType, flowController: RxDataFlowController<T>) -> Observable<RxStateType> {
        switch action {
        case let a as ChangeTextValueWithCustomDelayAction: return changeTextValueWithCustomDelayDescriptor(newText: a.newText)
            //Observable.just(TestState(text: (actionResult as! RxDefaultActionResult).value))
        //case _ as CompletionAction: return Observable.just(TestState(text: "Completed"))
        //case _ as ChangeTextValueAction: return Observable.just(TestState(text: (actionResult as! RxDefaultActionResult).value))
        default: return Observable.empty()
        }
    }
}
/*
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
			guard next.setBy is ChangeTextValueWithCustomDelayAction else { return }
			XCTAssertEqual(next.state.text, "New text")
			completeExpectation.fulfill()
		})
		
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text"))
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(store.stateStack.count, 2)
		XCTAssertEqual(store.stateStack.peek()?.state.text, "New text")
		XCTAssertTrue(store.stateStack.peek()?.setBy is ChangeTextValueWithCustomDelayAction)
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
			store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text \(i)"))
		}
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(store.stateStack.count, 10)
		XCTAssertEqual(store.stateStack.pop()?.state.text, "New text 10")
		XCTAssertEqual(store.stateStack.first()?.state.text, "New text 1")
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
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 1"))
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text before error"))
		store.dispatch(ErrorAction())
		
		waitForExpectations(timeout: 1, handler: nil)
	}
	
	func testContinueWorkAfterErrorAction() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		var changeTextValueActionCount = 0
		_ = store.state.filter { $0.setBy is ChangeTextValueWithCustomDelayAction }.subscribe(onNext: { next in
			changeTextValueActionCount += 1
		})
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 1"))
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 2"))
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 3"))
		store.dispatch(ErrorAction())
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 4"))
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "Last text change"))
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual(5, changeTextValueActionCount, "Should change text five times")
		XCTAssertEqual("Completed", store.stateValue.state.text)
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "New text 1",
		                                      "New text 2",
		                                      "New text 3",
		                                      "New text 4",
		                                      "Last text change",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testSerialActionDispatch() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
	
		let delayScheduler = SerialDispatchQueueScheduler(qos: .utility)
		
		for i in 1...11 {
			let after = (i % 2 == 0) ? 0.05 : 0
			let action: RxActionType = {
				if i == 11 {
					return CompletionAction()
				} else if i % 3 == 0 {
					let actionWork = RxActionWork {_ in
						return Observable.error(TestError.someError).delaySubscription(after, scheduler: delayScheduler)
					}
					
					return RxDefaultAction(work: actionWork)
				} else {
					return ChangeTextValueWithCustomDelayAction(newText: "Action \(i) executed", subscriptionDelay: after, scheduler: delayScheduler)
				}
			}()
			
			store.dispatch(action)
		}
		
		waitForExpectations(timeout: 3, handler: nil)
		
		let expectedStateHistoryTextValues = ["Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 4 executed",
		                                      "Action 5 executed",
		                                      "Action 7 executed",
		                                      "Action 8 executed",
		                                      "Action 10 executed",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatch_1() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"))
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 1"))
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.01) { store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 2")) }
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.1) { store.dispatch(ChangeTextValueWithCustomDelayAction(newText: "New text 3")) }
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.30) { store.dispatch(CompletionAction()) }
		
		waitForExpectations(timeout: 1, handler: nil)
		
		XCTAssertEqual("Completed", store.stateValue.state.text)
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "New text 1",
		                                      "New text 2",
		                                      "New text 3",
		                                      "Completed"]
		
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInCorrectScheduler_1() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action1Scheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let action1Work = RxActionWork(scheduler: action1Scheduler) { _ in
			return Observable.create { observer in
				observer.onNext(RxDefaultActionResult("Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		let action1 = ChangeTextValueAction(work: action1Work)
		store.dispatch(action1)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Completed"]
		
		XCTAssertEqual(1, action1Scheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInCorrectScheduler_2() {
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let actionScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		
		let action1Work = RxActionWork(scheduler: actionScheduler) { _ in
			return Observable.create { observer in
				observer.onNext(RxDefaultActionResult("Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		let action1 = ChangeTextValueAction(work: action1Work)
		
		let action2Work = RxActionWork(scheduler: actionScheduler) { _ in
			return Observable.create { observer in
				observer.onNext(RxDefaultActionResult("Action 2 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		let action2 = ChangeTextValueAction(work: action2Work)
		
		let action3Work = RxActionWork(scheduler: actionScheduler) { _ in
			return Observable.create { observer in
				observer.onNext(RxDefaultActionResult("Action 3 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		let action3 = ChangeTextValueAction(work: action3Work)
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Completed"]
		
		XCTAssertEqual(3, actionScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInDefaultScheduler() {
		let storeScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8, scheduler: storeScheduler)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action1Work = RxActionWork { _ in
			return Observable.create { observer in
				observer.onNext(RxDefaultActionResult("Action 1 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		let action1 = ChangeTextValueAction(work: action1Work)
		
		let action2Work = RxActionWork { _ in
			return Observable.create { observer in
				observer.onNext(RxDefaultActionResult("Action 2 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		let action2 = ChangeTextValueAction(work: action2Work)
		
		let action3Scheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let action3Work = RxActionWork(scheduler: action3Scheduler) { _ in
			return Observable.create { observer in
				observer.onNext(RxDefaultActionResult("Action 3 executed"))
				observer.onCompleted()
				return Disposables.create()
			}
		}
		let action3 = ChangeTextValueAction(work: action3Work)
		
		store.dispatch(action1)
		store.dispatch(action2)
		store.dispatch(action3)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Action 2 executed",
		                                      "Action 3 executed",
		                                      "Completed"]
		
		XCTAssertEqual(3, storeScheduler.scheduleCounter)
		XCTAssertEqual(1, action3Scheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
	
	func testDispatchInMainScheduer() {
		let storeScheduler = TestScheduler(internalScheduler: SerialDispatchQueueScheduler(qos: .utility))
		let store = RxStore(reducer: TestStoreReducer(), initialState: TestState(text: "Initial value"), maxHistoryItems: 8, scheduler: storeScheduler)
		let completeExpectation = expectation(description: "Should perform all non-error actions")
		
		_ = store.state.filter { $0.setBy is CompletionAction }.subscribe(onNext: { next in
			completeExpectation.fulfill()
		})
		
		let action1Work = RxActionWork(scheduler: MainScheduler.instance) { _ -> RxActionResultType in
				XCTAssertTrue(Thread.isMainThread)
				return RxDefaultActionResult("Action 1 executed")
		}
		let action1 = ChangeTextValueAction(work: action1Work)
		
		store.dispatch(action1)
		store.dispatch(CompletionAction())
		
		waitForExpectations(timeout: 1, handler: nil)
		
		let expectedStateHistoryTextValues = ["Initial value",
		                                      "Action 1 executed",
		                                      "Completed"]
		
		XCTAssertEqual(1, storeScheduler.scheduleCounter)
		XCTAssertEqual(expectedStateHistoryTextValues, store.stateStack.array.flatMap { $0 }.map { $0.state.text })
	}
}*/
