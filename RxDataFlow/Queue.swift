//
//  Queue.swift
//  RxDataFlow
//
//  Created by Anton Efimenko on 30.12.2017.
//  Copyright © 2017 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

struct Queue<T> {
	var array = [T?]()
	var head = 0
	
	let currentItemSubject = PublishSubject<T>()
	
	var isEmpty: Bool {
		return count == 0
	}
	
	var count: Int {
		return array.count - head
	}
	
	mutating func enqueue(_ element: T) {
		array.append(element)
		if count == 1 {
			self.currentItemSubject.onNext(element)
		}
	}
	
	mutating func dequeue() -> T? {
		guard head < array.count, let element = array[head] else { return nil }
		
		array[head] = nil
		head += 1
		
		let percentage = Double(head)/Double(array.count)
		if array.count > 50 && percentage > 0.25 {
			array.removeFirst(head)
			head = 0
		}
		
		if let current = peek() {
			currentItemSubject.onNext(current)
		}
		
		return element
	}
	
	func peek() -> T? {
		if isEmpty {
			return nil
		} else {
			return array[head]
		}
	}
}
