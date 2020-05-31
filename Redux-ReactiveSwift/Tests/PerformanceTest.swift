//
//  PerformanceTest.swift
//  CocoaPods-Redux-ReactiveSwift-iOSTests
//
//  Created by Petro Korienev on 5/29/20.
//

import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Redux_ReactiveSwift
import UIKit

fileprivate class Const {
    static let timeout: TimeInterval = 5
    static let writeCount: Int = 1000
    static let writeSum: Int = (Const.writeCount - 1) * Const.writeCount / 2 // sum (0 ... n-1) == (n - 1) * n / 2
    static let readMultiplicator: Int = 100
    
    static let toManyReadMultiplicator: Int = 10
    static let toManyMultiplicator: Int = 10
    static let toManySum = Const.toManyMultiplicator * Const.writeSum
    static let toManyResultCount: Int = Const.toManyMultiplicator * Const.writeCount
}

class BasePerformanceTest: XCTestCase {
    var writeQueue: DispatchQueue { return .init(label: "com.queue.write", qos: .default) }
    var readQueue: DispatchQueue { return .init(label: "com.queue.read", qos: .default) }
    var readScheduler: QueueScheduler { return .init(qos: .default, name: "", targeting: readQueue) }
    
    override class var defaultPerformanceMetrics: [XCTPerformanceMetric] {
        return [
            .wallClockTime,
            .runTime,
            .systemTime,
            .userTime,
            .totalHeapKB
        ]
    }
    
    func testPerformance<S>(timeout: TimeInterval = Const.timeout,
                            setupClosure: () -> S,
                            measureClosure: (S) -> ()) where S: StoreProtocol {
        measure {
            measureClosure(setupClosure())
            self.waitForExpectations(timeout: timeout) { error in
                self.stopMeasuring()
                if let error = error { print(error) }
            }
        }
    }
    
    func testMultiplePerformance<S>(timeout: TimeInterval = Const.timeout,
                                    multiplicationFactor: Int = Const.toManyMultiplicator,
                                    setupClosure: (Int) -> [S],
                                    measureClosure: ([S]) -> ()) where S: StoreProtocol {
        measure {
            measureClosure(setupClosure(multiplicationFactor))
            self.waitForExpectations(timeout: timeout) { error in
                self.stopMeasuring()
                if let error = error { print(error) }
            }
        }
    }
}

class ConstantTime: BasePerformanceTest {
    lazy var setupClosure = { () -> Store<Int, Int> in
        return StoreBuilder<Int, Int, Store<Int, Int>>()
            .reducer({ $0 + $1 })
            .scheduleRead(on: self.readScheduler)
            .build()
    }
}

class LinearTime: BasePerformanceTest {
    lazy var setupClosure = { () -> Store<[Int], Int> in
        return StoreBuilder<[Int], Int, Store<[Int], Int>>(state: [])
            .reducer({ $0 + [$1] })
            .scheduleRead(on: self.readScheduler)
            .build()
    }
}

class LinearLogarithmicTime: BasePerformanceTest {
    struct State {
        let data: [StateSlice]; struct StateSlice {
            let data: [Int]
        }
        static func reduce(state: State, action: Int) -> State {
            return State(
                data: [StateSlice(data: [action])] +
                    state.data.map { StateSlice(data: $0.data + [action]) }
            )
        }
    }
    
    lazy var setupClosure = { () -> Store<State, Int> in
        return StoreBuilder<State, Int, Store<State, Int>>(state: State(data: []))
            .reducer(State.reduce)
            .scheduleRead(on: self.readScheduler)
            .build()
    }
}

extension ConstantTime {
    @objc func testOneToOnePerformance() {
        testPerformance(setupClosure: self.setupClosure) { (store) in
            let exp = self.expectation(description: "Wait for store to synchronize")
            store.producer.startWithValues { (value) in
                if value == Const.writeSum {
                    exp.fulfill()
                }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    store.consume(event: i)
                }
            }
        }
    }
    
    @objc func testOneToManyPerformance() {
        testPerformance(setupClosure: self.setupClosure) { (store) in
            for _ in 0 ..< Const.readMultiplicator {
                let exp = self.expectation(description: "Wait for store to synchronize")
                store.producer.startWithValues { (value) in
                    if value == Const.writeSum { exp.fulfill() }
                }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    store.consume(event: i)
                }
            }
        }
    }
    
    @objc func testManyToManyPerformance() {
        testMultiplePerformance(setupClosure: { (0 ..< $0).map { _ in self.setupClosure() } }) { (stores) in
            for _ in 0 ..< Const.toManyReadMultiplicator {
                let exp = self.expectation(description: "Wait for store to synchronize")
                SignalProducer.zip( stores.map { $0.producer }).startWithValues { (value) in
                    if value.reduce(0, +) == Const.toManySum { exp.fulfill() }
                }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    stores.forEach { $0.consume(event: i) }
                }
            }
        }
    }
}

extension LinearTime {
    @objc func testOneToOnePerformance() {
        testPerformance(setupClosure: self.setupClosure) { (store) in
            let exp = self.expectation(description: "Wait for store to synchronize")
            store.producer.startWithValues { (value) in
                if value.count == Const.writeCount { exp.fulfill() }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    store.consume(event: i)
                }
            }
        }
    }
    
    @objc func testOneToManyPerformance() {
        testPerformance(setupClosure: self.setupClosure) { (store) in
            for _ in 0 ..< Const.readMultiplicator {
                let exp = self.expectation(description: "Wait for store to synchronize")
                store.producer.startWithValues { (value) in
                    if value.count == Const.writeCount { exp.fulfill() }
                }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    store.consume(event: i)
                }
            }
        }
    }
    
    @objc func testManyToManyPerformance() {
        testMultiplePerformance(setupClosure: { (0 ..< $0).map { _ in self.setupClosure() } }) { (stores) in
            for _ in 0 ..< Const.toManyReadMultiplicator {
                let exp = self.expectation(description: "Wait for store to synchronize")
                SignalProducer.zip( stores.map { $0.producer }).startWithValues { (value) in
                    let totalCount = value.reduce(into: 0) { $0 = $0 + $1.count }
                    if totalCount == Const.toManyResultCount { exp.fulfill() }
                }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    stores.forEach { $0.consume(event: i) }
                }
            }
        }
    }
}

extension LinearLogarithmicTime {
    @objc func testOneToOnePerformance() {
        testPerformance(setupClosure: self.setupClosure) { (store) in
            let exp = self.expectation(description: "Wait for store to synchronize")
            store.producer.startWithValues { (value) in
                if value.data.count == Const.writeCount { exp.fulfill() }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    store.consume(event: i)
                }
            }
        }
    }
    
    @objc func testOneToManyPerformance() {
        testPerformance(setupClosure: self.setupClosure) { (store) in
            for _ in 0 ..< Const.readMultiplicator {
                let exp = self.expectation(description: "Wait for store to synchronize")
                store.producer.startWithValues { (value) in
                    if value.data.count == Const.writeCount { exp.fulfill() }
                }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    store.consume(event: i)
                }
            }
        }
    }
    
    @objc func testManyToManyPerformance() {
        testMultiplePerformance(timeout: 10, setupClosure: { (0 ..< $0).map { _ in self.setupClosure() } }) { (stores) in
            for _ in 0 ..< Const.toManyReadMultiplicator {
                let exp = self.expectation(description: "Wait for store to synchronize")
                SignalProducer.zip( stores.map { $0.producer }).startWithValues { (value) in
                    let totalCount = value.reduce(into: 0) { $0 = $0 + $1.data.count }
                    if totalCount == Const.toManyResultCount { exp.fulfill() }
                }
            }
            writeQueue.async {
                for i in 0 ..< Const.writeCount {
                    stores.forEach { $0.consume(event: i) }
                }
            }
        }
    }
}
