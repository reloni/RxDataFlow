//
//  FixedStackTests.swift
//  RxState
//
//  Created by Anton Efimenko on 06.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import XCTest
@testable import RxDataFlow

class FixedQueueTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testDequeueWhenExceedsCapacity() {
		var stack = FixedStack<Int>(capacity: 5)

		stack.push(1)
		stack.push(2)
		stack.push(3)
		stack.push(4)
		stack.push(5)
		XCTAssertEqual([1, 2, 3, 4, 5], stack.array.flatMap { $0 })
		
		stack.push(6)
		XCTAssertEqual([2, 3, 4, 5, 6], stack.array.flatMap { $0 })
		XCTAssertEqual(6, stack.array.count)
		XCTAssertEqual(5, stack.count)
		XCTAssertEqual(6, stack.peek())
	}
	
	func testTrimInternalArray() {
		var stack =	FixedStack<Int>(capacity: 35)
		
		for i in 0..<50 {
			stack.push(i)
		}

		XCTAssertEqual(50, stack.array.count)
		XCTAssertEqual(35, stack.count)
		
		stack.push(50)
		
		XCTAssertEqual(35, stack.array.count)
		XCTAssertEqual(35, stack.count)
	}
	
	func testPopAndRevertHead() {
		var stack = FixedStack<Int>(capacity: 5)
		
		for i in 0..<10 {
			stack.push(i)
		}
		
		XCTAssertEqual(10, stack.array.count)
		
		XCTAssertEqual(5, stack.head)
		for _ in 0..<9 {
			_ = stack.pop()
		}
		
		XCTAssertEqual(0, stack.count)
		XCTAssertEqual(1, stack.head)
		XCTAssertEqual(1, stack.array.count)
		
		XCTAssertNil(stack.pop())
		XCTAssertEqual(0, stack.count)
		XCTAssertEqual(0, stack.head)
		XCTAssertEqual(0, stack.array.count)
		
		XCTAssertNil(stack.pop())
		XCTAssertEqual(0, stack.count)
		XCTAssertEqual(0, stack.head)
		XCTAssertEqual(0, stack.array.count)
	}
	
	func testPushAndPop() {
		var stack = FixedStack<Int>(capacity: 5)
		
		for i in 0..<10 {
			stack.push(i)
		}
		
		XCTAssertEqual(9, stack.peek())
		
		XCTAssertEqual(9, stack.pop())
		XCTAssertEqual(8, stack.pop())
		XCTAssertEqual(3, stack.count)
		
		stack.push(15)
		XCTAssertEqual(15, stack.peek())
		XCTAssertEqual(4, stack.count)
		XCTAssertEqual([5, 6, 7, 15], stack.array.flatMap { $0 })
		XCTAssertEqual(5, stack.head)
	}
	
	func testPopElement() {
		var stack = FixedStack<Int>(capacity: 5)
		stack.push(1)
		stack.push(2)
		stack.push(3)
		
		XCTAssertEqual(3, stack.pop())
		XCTAssertEqual(2, stack.count)
		
		XCTAssertEqual(2, stack.pop())
		XCTAssertEqual(1, stack.count)
		
		XCTAssertEqual(1, stack.pop())
		XCTAssertEqual(0, stack.count)
		
		XCTAssertNil(stack.pop())
		XCTAssertEqual(0, stack.count)
	}
}
