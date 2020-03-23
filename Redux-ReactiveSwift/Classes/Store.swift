//
//  Store.swift
//  Redux-ReactiveSwift
//
//  Created by Petro Korienev on 10/12/17.
//  Copyright © 2017 Petro Korienev. All rights reserved.
//

import Foundation
import ReactiveSwift

public protocol Defaultable {
  static var defaultValue: Self { get }
}

infix operator <~ : BindingPrecedence

open class Store<State, Event> {
  
  public typealias Reducer = (State, Event) -> State
  
  fileprivate var innerProperty: MutableProperty<State>
  fileprivate var reducers: [Reducer]
  fileprivate var middlewares: [StoreMiddleware] = []
  fileprivate let readScheduler: QueueScheduler
  
  public required init(state: State, reducers: [Reducer], readScheduler: QueueScheduler? = nil) {
    self.innerProperty = MutableProperty<State>(state)
    self.readScheduler = readScheduler ?? .main
    self.reducers = reducers
    readScheduler?.queue.recursiveSyncEnabled = true
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
    innerProperty.value = reducers.reduce(self.innerProperty.value) { $1($0, event) }
  }
  
  private func register(middleware: StoreMiddleware) {
    self.innerProperty.signal.observeValues { middleware.stateDidChange(state: $0) }
    middleware.unsafeValue()?.observeValues { [weak self] value in
      guard let safeValue = value as? State else {
        fatalError("Store got \(value) from unsafeValue() signal which is not of \(String(describing:State.self)) type")
      }
      
      self?.innerProperty.value = safeValue
    }
  }
}

extension Store: PropertyProtocol {
  public var value: State {
    readScheduler.queue.recursiveSync { innerProperty.value }
  }
  
  public var producer: SignalProducer<State, Never> {
    SignalProducer<State, Never> { [weak self] observer, lifetime in
      guard let self = self else { return observer.sendCompleted() }
      observer.send(value: self.value)
      lifetime += self.signal.observe(observer)
    }
  }
  
  public var signal: Signal<State, Never> {
    innerProperty.signal.observe(on: readScheduler)
  }
}

public extension Store {
  @discardableResult
  static func <~ <Source: BindingSource> (target: Store<State, Event>, source: Source) -> Disposable?
    where Event == Source.Value
  {
    return source.producer
      .take(during: target.innerProperty.lifetime)
      .startWithValues(target.consume)
  }
}

public extension Store where State: Defaultable {
  convenience init(reducers: [Reducer], readScheduler: QueueScheduler? = nil) {
    self.init(
      state: State.defaultValue,
      reducers: reducers,
      readScheduler: readScheduler)
  }
}
