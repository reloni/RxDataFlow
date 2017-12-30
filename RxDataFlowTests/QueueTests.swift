//
//  QueueTests.swift
//  RxDataFlow
//
//  Created by Anton Efimenko on 17.03.17.
//  Copyright © 2017 Anton Efimenko. All rights reserved.
//

import XCTest
@testable import RxDataFlow

class QueueTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testTrimInternalArray() {
		var queue = Queue<Int>()
		
		for i in 0..<1000 {
			queue.enqueue(i)
		}
		
		XCTAssertEqual(queue.array.count, 1000)
		XCTAssertEqual(queue.head, 0)
		
		for _ in 0..<250 {
			_ = queue.dequeue()
		}
		
		XCTAssertEqual(queue.array.count, 1000)
		XCTAssertEqual(queue.head, 250)
		
		_ = queue.dequeue()
		
		XCTAssertEqual(queue.array.count, 749)
		XCTAssertEqual(queue.head, 0)
	}
}
