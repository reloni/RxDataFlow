//
//  FixedStack.swift
//  RxState
//
//  Created by Anton Efimenko on 06.11.16.
//  Copyright © 2016 Anton Efimenko. All rights reserved.
//

import Foundation

struct FixedStack<T> {
	let capacity: UInt
	
	var array = [T?]()
	var head = 0
	
	
	public var isEmpty: Bool {
		return count == 0
	}
	
	var count: Int {
		return array.count - head
	}
	
	init(capacity: UInt = 50) {
		self.capacity = capacity
	}
	
	mutating func push(_ element: T) {
		array.append(element)
		dequeue()
	}
	
	mutating func pop() -> T? {
		let element = array.popLast() ?? nil
		if array.count < head { head = array.count }
		return element
	}
	
	private mutating func dequeue() {
		guard UInt(count) > capacity else { return }
		
		guard head < array.count, let _ = array[head] else { return }
		
		array[head] = nil
		head += 1
		
		let percentage = Double(head)/Double(array.count)
		if array.count > 50 && percentage > 0.25 {
			array.removeFirst(head)
			head = 0
		}
	}
	
	func peek() -> T? {
		if isEmpty {
			return nil
		} else {
			return array.last ?? nil
		}
	}
}
