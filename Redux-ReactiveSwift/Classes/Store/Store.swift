//
//  Store.swift
//  Redux-ReactiveSwift
//
//  Created by Petro Korienev on 10/12/17.
//  Copyright © 2017 Petro Korienev. All rights reserved.
//

import Foundation
import ReactiveSwift

open class Store<State, Event>: StoreProtocol {
  fileprivate var innerProperty: MutableProperty<State>
  fileprivate var reducers: [Reducer<State, Event>]
  fileprivate var middlewares: [StoreMiddleware] = []
  fileprivate let readScheduler: QueueScheduler
  
  fileprivate var _state: State
  fileprivate var _producer: SignalProducer<State, Never> = .empty
  fileprivate var _signal: Signal<State, Never> = .empty
  
  public var lifetime: Lifetime {
    return innerProperty.lifetime
  }
  
  public required init(state: State, reducers: [Reducer<State, Event>], readScheduler: QueueScheduler = .main) {
    self.innerProperty = MutableProperty<State>(state)
    self.readScheduler = readScheduler
    self.reducers = reducers
    
    self._state = state
    self._signal = innerProperty.signal.observe(on: readScheduler)
    self._producer = SignalProducer<State, Never> { [weak self] observer, lifetime in
      guard let self = self else { return observer.sendCompleted() }
      observer.send(value: self._state)
      lifetime += self._signal.observe(observer)
    }
  }
  
  public func applyMiddlewares(_ middlewares: [StoreMiddleware]) -> Self {
    guard self.middlewares.count == 0 else {
      fatalError("Applying middlewares more than once is yet unsupported")
    }
    self.middlewares = middlewares
    self.middlewares.forEach(self.register(middleware:))
    return self
  }
  
  public func consume(event: Event) {
    consume(event: event, with: middlewares)
  }
  
  private func consume(event: Event, with middlewares: [StoreMiddleware]) {
    guard middlewares.count > 0 else { return undecoratedConsume(event: event) }
    let slicedMiddlewares = Array(middlewares.dropFirst())
    if let signal = middlewares.first?.consume(event: event) {
      signal.startWithValues { [weak self] value in self?.consume(event: value, with: slicedMiddlewares) }
    } else {
      self.consume(event: event, with: slicedMiddlewares)
    }
  }
  
  public func undecoratedConsume(event: Event) {
    let newState = reducers.reduce(self.innerProperty.value) { $1($0, event) }
    readScheduler.schedule { self._state = newState }
    innerProperty.value = newState
  }
  
  private func register(middleware: StoreMiddleware) {
    self.innerProperty.signal.observeValues { middleware.stateDidChange(state: $0) }
    middleware.unsafeValue()?.observeValues { [weak self] value in
      guard let safeValue = value as? State else {
        fatalError("Store got \(value) from unsafeValue() signal which is not of \(String(describing:State.self)) type")
      }
      self?.readScheduler.schedule { self?._state = safeValue }
      self?.innerProperty.value = safeValue
    }
  }
}

extension Store: PropertyProtocol {
  public var value: State {
    return self._state
  }
  public var producer: SignalProducer<State, Never> {
    return _producer
  }
  public var signal: Signal<State, Never> {
    return _signal
  }
}

public extension Store where State: Defaultable {
    convenience init(reducers: [Reducer<State, Event>], readScheduler: QueueScheduler = .main) {
    self.init(
      state: State.defaultValue,
      reducers: reducers,
      readScheduler: readScheduler)
  }
}
