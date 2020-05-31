//
//  StrongConsistencyStore.swift
//  CocoaPods-Redux-ReactiveSwift-iOS
//
//  Created by Petro Korienev on 5/31/20.
//


import Foundation
import ReactiveSwift

fileprivate extension DispatchQueue {
    private struct Const {
        static let rSyncKey = DispatchSpecificKey<NSString>()
    }
    var recursiveSyncEnabled: Bool {
        set { self.setSpecific(key: Const.rSyncKey, value: newValue ? (label as NSString) : nil)}
        get { self.getSpecific(key: Const.rSyncKey) != nil }
    }
    func recursiveSync<T>(_ closure: () -> T) -> T {
        let specific = DispatchQueue.getSpecific(key: Const.rSyncKey)
        return (specific != nil && specific == self.getSpecific(key: Const.rSyncKey)) ?
            closure() :
            sync(execute: closure)
    }
}

public final class StrongConsistencyStore<State, Event>: StoreProtocol {

  public typealias Reducer = (State, Event) -> State

  fileprivate var innerProperty: MutableProperty<State>
  fileprivate var reducers: [Reducer]
  fileprivate var middlewares: [StoreMiddleware] = []
  fileprivate let readScheduler: QueueScheduler
    
  public var lifetime: Lifetime {
    return innerProperty.lifetime
  }

  public required init(state: State, reducers: [Reducer], readScheduler: QueueScheduler = .main) {
    readScheduler.queue.recursiveSyncEnabled = true
    
    self.innerProperty = MutableProperty<State>(state)
    self.readScheduler = readScheduler
    self.reducers = reducers
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

extension StrongConsistencyStore: PropertyProtocol {
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

public extension StrongConsistencyStore where State: Defaultable {
  convenience init(reducers: [Reducer], readScheduler: QueueScheduler = .main) {
    self.init(
      state: State.defaultValue,
      reducers: reducers,
      readScheduler: readScheduler)
  }
}

