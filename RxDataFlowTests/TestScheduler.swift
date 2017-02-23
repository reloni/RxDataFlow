//
//  TestScheduler.swift
//  RxState
//
//  Created by Anton Efimenko on 01.01.17.
//  Copyright © 2017 Anton Efimenko. All rights reserved.
//

import Foundation
import RxSwift

final class TestScheduler : ImmediateSchedulerType {
	let internalScheduler: SchedulerType
	var scheduleCounter = 0
	init(internalScheduler: SchedulerType) {
		self.internalScheduler = internalScheduler
	}
	func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
		if state is ScheduledDisposable {
			scheduleCounter += 1
		}
		return internalScheduler.schedule(state, action: action)
	}
}
