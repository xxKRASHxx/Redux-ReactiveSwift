//
//  StoreMiddleware.swift
//  Redux-ReactiveSwift
//
//  Created by Petro Korienev on 1/1/18.
//

import Foundation
import ReactiveSwift

public protocol StoreMiddleware {
    func consume<Event>(event: Event) -> SignalProducer<Event, Never>?
    func stateDidChange<State>(state: State)
    func unsafeValue() -> Signal<Any, Never>?
}
