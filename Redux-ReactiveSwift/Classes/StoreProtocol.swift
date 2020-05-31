//
//  StoreProtocol.swift
//  CocoaPods-Redux-ReactiveSwift-iOS
//
//  Created by Petro Korienev on 5/31/20.
//

import Foundation
import ReactiveSwift

public protocol StoreProtocol {
    associatedtype State
    associatedtype Event
    associatedtype Reducer
    
    func applyMiddlewares(_ middlewares: [StoreMiddleware]) -> Self
    func consume(event: Event)
    func undecoratedConsume(event: Event)
    
    var lifetime: Lifetime { get }
    
    init(state: State, reducers: [Reducer], readScheduler: QueueScheduler)
}


infix operator <~ : BindingPrecedence

public extension StoreProtocol where Self: PropertyProtocol {
    @discardableResult
    static func <~ <Source: BindingSource> (target: Self, source: Source) -> Disposable?
        where Event == Source.Value
    {
      return source.producer
        .take(during: target.lifetime)
        .startWithValues(target.consume)
    }
}
