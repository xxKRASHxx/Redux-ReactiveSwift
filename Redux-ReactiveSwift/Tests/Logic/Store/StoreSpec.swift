//
//  StoreSpec.swift
//  Redux-ReactiveSwiftTests
//
//  Created by Petro Korienev on 10/15/17.
//  Copyright © 2017 Petro Korienev. All rights reserved.
//

import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Redux_ReactiveSwift
import UIKit

class StoreSpec: QuickSpec {
    fileprivate typealias Helper = StoreSpecHelpers
    override func spec() {
        describe("Reducers processing") {
            context("single reducer") {
                it("should call reducer on event") {
                    let (store, reducer) = Helper.createStore(reducer: Helper.intReducer, initialValue: 0)
                    store.consume(event: .increment)
                    expect(reducer.callCount).to(equal(1))
                }
                it("should call reducer once on each event") {
                    let (store, reducer) = Helper.createStore(reducer: Helper.intReducer, initialValue: 0)
                    store.consume(event: .increment)
                    store.consume(event: .decrement)
                    store.consume(event: .add(1))
                    store.consume(event: .subtract(1))
                    expect(reducer.callCount).to(equal(4))
                }
                it("should fire signal on event") {
                    let (store, _) = Helper.createStore(reducer: Helper.intReducer, initialValue: 0)
                    let observer = Helper.observeValues(of: store, with: Helper.observeIntValues)
                    store.consume(event: .increment)
                    expect(observer.callCount).toEventually(equal(1), timeout: 0.1)
                }
                it("should fire signal on each event") {
                    let (store, _) = Helper.createStore(reducer: Helper.intReducer, initialValue: 0)
                    let observer = Helper.observeValues(of: store, with: Helper.observeIntValues)
                    store.consume(event: .increment)
                    store.consume(event: .decrement)
                    store.consume(event: .add(1))
                    store.consume(event: .subtract(1))
                    expect(observer.callCount).toEventually(equal(4), timeout: 0.1)
                }
            }
            context("multiple reducers") {
                it("should call every reducer once on event") {
                    let (store, reducer1, reducer2) = Helper.createStore(reducers: Helper.intReducer, Helper.intReducer, initialValue: 0)
                    store.consume(event: .increment)
                    expect(reducer1.callCount).to(equal(1))
                    expect(reducer2.callCount).to(equal(1))
                }
                it("should call every reducer once on each event") {
                    let (store, reducer1, reducer2) = Helper.createStore(reducers: Helper.intReducer, Helper.intReducer, initialValue: 0)
                    store.consume(event: .increment)
                    store.consume(event: .decrement)
                    store.consume(event: .add(1))
                    store.consume(event: .subtract(1))
                    expect(reducer1.callCount).to(equal(4))
                    expect(reducer2.callCount).to(equal(4))
                }
                it("should fire signal on event") {
                    let store = Helper.createStore(reducers: [Helper.intReducer, Helper.intReducer, Helper.intReducer], initialValue: 0)
                    let observer = Helper.observeValues(of: store, with: Helper.observeIntValues)
                    store.consume(event: .increment)
                    expect(observer.callCount).toEventually(equal(1), timeout: 0.1)
                }
                it("should fire signal on each event") {
                    let store = Helper.createStore(reducers: [Helper.intReducer, Helper.intReducer, Helper.intReducer], initialValue: 0)
                    let observer = Helper.observeValues(of: store, with: Helper.observeIntValues)
                    store.consume(event: .increment)
                    store.consume(event: .decrement)
                    store.consume(event: .add(1))
                    store.consume(event: .subtract(1))
                    expect(observer.callCount).toEventually(equal(4), timeout: 0.1)
                }
            }
        }
        describe("Value-type state") {
            context("value") {
                context("single reducer") {
                    it("should calculate value by reducer") {
                        let (store, _) = Helper.createStore(reducer: Helper.intReducer, initialValue: 0)
                        store.consume(event: .increment)
                        expect(store.value)
                            .toEventually(equal(Helper.intReducer(state: 0, event: .increment)), timeout: 0.1)
                    }
                    it("should calculate values by reducer on each event") {

                        let (store, _) = Helper.createStore(reducer: Helper.intReducer, initialValue: 0)
                        store.consume(event: .increment)
                        expect(store.value)
                            .toEventually(equal(Helper.intReducer(state: 0, event: .increment)), timeout: 0.1)

                        let state = store.value
                        store.consume(event: .decrement)
                        expect(store.value)
                            .toEventually(equal(Helper.intReducer(state: state, event: .decrement)), timeout: 0.1)
                    }
                }
                context("multiple reducers") {
                    let reducers = [Helper.intReducer, Helper.intReducer, Helper.intReducer]
                    it("should calculate value by reducer") {
                        let store = Helper.createStore(reducers: reducers, initialValue: 0)
                        store.consume(event: .increment)
                        let result = reducers.reduce(0, { state, reducer in reducer(state, .increment) })
                        expect(store.value)
                            .toEventually(equal(result), timeout: 0.1)
                    }
                    it("should calculate values by reducer on each event") {
                        let store = Helper.createStore(reducers: reducers, initialValue: 0)
                        store.consume(event: .increment)
                        let result = reducers.reduce(0, { state, reducer in reducer(state, .increment) })
                        expect(store.value)
                            .toEventually(equal(result), timeout: 0.1)

                        let state = store.value
                        store.consume(event: .decrement)
                        let nextResult = reducers.reduce(state, { state, reducer in reducer(state, .decrement) })
                        expect(store.value)
                            .toEventually(equal(nextResult), timeout: 0.1)
                    }
                }
            }
            context("signal producer") {
                it("should produce valid sequence of values") {
                    let (store, _) = Helper.createStore(reducer: Helper.intReducer, initialValue: 0)
                    let observer = Helper.observeValuesViaProducer(of: store, with: Helper.observeIntValues)

                    store.consume(event: .increment)
                    store.consume(event: .decrement)
                    store.consume(event: .add(1))
                    store.consume(event: .subtract(1))

                    expect((observer.arrayForAllCallsForArgument(at: 0) as! [Int]))
                        .toEventually(equal([0, 1, 0, 1, 0]), timeout: 0.1)
                }
            }
        }
        describe("Reference-type state") {
            let initialState = 0 as NSNumber
            context("value") {
                context("single reducer") {
                    it("should calculate value by reducer") {
                        let (store, _) = Helper.createStore(reducer: Helper.nsNumberReducer, initialValue: initialState)
                        store.consume(event: .increment)
                        expect(store.value)
                            .toEventually(equal(Helper.nsNumberReducer(state: initialState, event: .increment)), timeout: 0.1)
                    }
                    it("should calculate values by reducer on each event") {
                        let (store, _) = Helper.createStore(reducer: Helper.nsNumberReducer, initialValue: initialState)
                        store.consume(event: .increment)
                        expect(store.value)
                            .toEventually(equal(Helper.nsNumberReducer(state: initialState, event: .increment)), timeout: 0.1)

                        let state = store.value
                        store.consume(event: .decrement)
                        expect(store.value)
                            .toEventually(equal(Helper.nsNumberReducer(state: state, event: .decrement)), timeout: 0.1)

                    }
                }
                context("multiple reducers") {
                    let reducers = [Helper.nsNumberReducer, Helper.nsNumberReducer, Helper.nsNumberReducer]
                    it("should calculate value by reducer") {
                        let store = Helper.createStore(reducers: reducers, initialValue: initialState)
                        store.consume(event: .increment)
                        let result = reducers.reduce(initialState, { state, reducer in reducer(state, .increment) })
                        expect(store.value)
                            .toEventually(equal(result), timeout: 0.1)
                    }

                    it("should calculate values by reducer on each event") {
                        let store = Helper.createStore(reducers: reducers, initialValue: initialState)
                        store.consume(event: .increment)
                        let result = reducers.reduce(initialState, { state, reducer in reducer(state, .increment) })
                        expect(store.value)
                            .toEventually(equal(result), timeout: 0.1)

                        let state = store.value
                        store.consume(event: .decrement)
                        let nextResult = reducers.reduce(state, { state, reducer in reducer(state, .decrement) })
                        expect(store.value)
                            .toEventually(equal(nextResult), timeout: 0.1)
                    }
                }
            }
            context("signal producer") {
                it("should produce valid sequence of values") {

                    let (store, _) = Helper.createStore(reducer: Helper.nsNumberReducer, initialValue: initialState)
                    let observer = Helper.observeValuesViaProducer(of: store, with: Helper.observeNumberValues)

                    store.consume(event: .increment)
                    store.consume(event: .decrement)
                    store.consume(event: .add(1))
                    store.consume(event: .subtract(1))

                    expect((observer.arrayForAllCallsForArgument(at: 0) as! [NSNumber]))
                        .toEventually(equal([0, 1, 0, 1, 0]), timeout: 0.1)
                }
            }
        }
        describe("Defaultable type state") {
            context("value") {
                it("should initialize with default value") {
                    let store: Store<Int, ()> = Store(reducers: [])
                    expect(store.value).to(equal(Int.defaultValue))
                }
            }
            context("signal producer") {
                it("should initialize with default value") {
                    let store: Store<Int, ()> = Store(reducers: [])
                    let observer = Helper.observeValuesViaProducer(of: store, with: Helper.observeIntValues)
                    expect((observer.arguments()[0] as! Int)).to(equal(Int.defaultValue))
                }
            }
        }
        describe("Value binding") {
            it("should deliver values to binding target") {
                let f: ([String]) -> () = { _ in }
                let callSpy = CallSpy.makeCallSpy(f1: f)

                let label = UILabel()
                label.reactive.producer(forKeyPath: "text")
                    .skipNil()
                    .map { $0 as! String }
                    .collect(count: 5)
                    .startWithValues(callSpy.1)

                let store = Helper.createStore(reducers: [Helper.stringReducer], initialValue: "Hello")
                label.reactive.text <~ store
                store.consume(event: .increment)
                store.consume(event: .decrement)
                store.consume(event: .add(4))
                store.consume(event: .subtract(5))

                expect((callSpy.0.arguments()[0] as! [String]))
                    .toEventually(equal(["Hello", "Hello1", "Hello", "Hello1234", "Hell"]), timeout: 0.1)
                
            }
            it("should accept values from the binding source") {
                let f: ([[String]]) -> () = { _ in }
                let callSpy = CallSpy.makeCallSpy(f1: f)
                
                let searchBar = UISearchBar()
                let searchSource = ["ReactiveCocoa", "ReactiveSwift", "Result", "Redux-ReactiveSwitft"]
                func reducer(state: [String], event: String) -> [String] {
                    return event.count > 0 ? searchSource.filter { $0.lowercased().starts(with: event.lowercased()) } : searchSource
                }
                
                let store = Store<[String], String>(state: [], reducers: [reducer])
                store <~ searchBar.reactive.continuousTextValues.skipNil()
                store.producer.collect(count: 7)
                    .startWithValues(callSpy.1)
                
                searchBar.text = "Re"
                searchBar.delegate?.searchBar?(searchBar, textDidChange: "Re")
                searchBar.text = "Rea"
                searchBar.delegate?.searchBar?(searchBar, textDidChange: "Rea")
                searchBar.text = "ReS"
                searchBar.delegate?.searchBar?(searchBar, textDidChange: "ReS")
                searchBar.text = "Red"
                searchBar.delegate?.searchBar?(searchBar, textDidChange: "Red")
                searchBar.text = "RA"
                searchBar.delegate?.searchBar?(searchBar, textDidChange: "RA")
                searchBar.text = ""
                searchBar.delegate?.searchBar?(searchBar, textDidChange: "")
                
                expect((callSpy.0.arguments()[0] as! [[String]]))
                    .toEventually(equal([
                        [],
                        searchSource,
                        ["ReactiveCocoa", "ReactiveSwift"],
                        ["Result"],
                        ["Redux-ReactiveSwitft"],
                        [],
                        searchSource
                    ]), timeout: 0.1)
            }
        }
    }
}
