# RxDataFlow

[![Build Status](https://travis-ci.org/reloni/RxDataFlow.svg?branch=master)](https://travis-ci.org/reloni/RxDataFlow)
[![codecov](https://codecov.io/gh/reloni/RxDataFlow/branch/master/graph/badge.svg)](https://codecov.io/gh/reloni/RxDataFlow)
![Platform iOS](https://img.shields.io/badge/platform-iOS-lightgray.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codebeat badge](https://codebeat.co/badges/7cf46f0c-96ad-4f11-b547-cfd021868765)](https://codebeat.co/projects/github-com-reloni-rxdataflow-master)

## Introduction
RxDataFlow is another implementation of unidirectional data flow architecture. This library is inspired by ReSwift (which was inspired by Redux).

More information will be added soon:)

## Components
- State: A data structure that describes state of application.
- Reducer: A pure function that creates new state on base on action and current state.
- Action: Actions describe state change. Reducer produce state changes according to dispatched action.
<img src="assets/FlowControllerSimple.png" width="100%" height="100%"/>

1. The `View Controller/View Model` creates an `Action` and dispatch it to the `FlowController`.

2. The `FlowController` switches to appropriate scheduler and sends the `State` and `Action` to the `Reducer`.

3. The `Reducer` receives the current `App State` and the dispatched `Action`, computes and returns **new** `State`.

4. The `FlowController` saves new `State` and sends it to the subscribers.
  - In case of an error `FlowController` doesn't change `State` and sends `Error` to all subscribers instead.
  - It's possible to setup special `FallbackAction` that will be dispatched in case of an error (see CompositeAction).

5. Subscriber receives new `State` and operate accordingly: `View Model` may transform `State`, `View Controller` may directly bind data to the UI.

## Dependencies
- [RxSwift](https://github.com/ReactiveX/RxSwift) >= 3.4.0

## Requirements
- Xcode 8.3
- Swift 3.1

## Installation
- Using [Carthage](https://github.com/Carthage/Carthage)
 ```
github "reloni/RxDataFlow" ~> 0.9.0
```

## Example Projects
[SimpleToDo](https://github.com/reloni/SimpleTodo) - kind of "real world" app using this architecture, already in app store.

## Credits
List of similar projects:
- [ReSwift](https://github.com/ReSwift/ReSwift)
- [ReactorKit](https://github.com/ReactorKit/ReactorKit)
- [RxState](https://github.com/RxSwiftCommunity/RxState)
