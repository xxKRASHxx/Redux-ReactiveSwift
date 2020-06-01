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

// MARK: - Auxiliary types for this performance test
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

fileprivate protocol StoreProviderProtocol {
    associatedtype S: StoreProtocol
    var store: S { get }
}

// MARK: - Base class to define measurement pattern and metrics

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

// MARK: - Type definitions for three types of test: constant time growth state O(1), linear O(n) and quadratic O(n^2)
class ConstantTime: BasePerformanceTest {}
class LinearTime: BasePerformanceTest {}
class QuadraticTime: BasePerformanceTest {}

// MARK: – Testing pattern for constant time. Can be applied to concrete store classes
extension ConstantTime {
    func oneToOne<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == Int, S.Event == Int, S.Value == Int {
            testPerformance(setupClosure: setupClosure) { (store) in
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
    
    func oneToMany<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == Int, S.Event == Int, S.Value == Int {
            testPerformance(setupClosure: setupClosure) { (store) in
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
    
    func manyToMany<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == Int, S.Event == Int, S.Value == Int {
            testMultiplePerformance(setupClosure: { (0 ..< $0).map { _ in setupClosure() } }) { (stores) in
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
    
    func lockIntensiveOperation<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == Int, S.Event == Int, S.Value == Int {
            testPerformance(setupClosure: setupClosure) { (store) in
                for _ in 0 ..< Const.readMultiplicator {
                    let exp = self.expectation(description: "Wait for store to synchronize")
                    var accumulator: Int = 0
                    store.producer.startWithValues { value in
                        accumulator = accumulator + store.value // Intensionally accessing store.value here to check locking behavior
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
}

// MARK: – Testing pattern for linear time. Can be applied to concrete store classes
extension LinearTime {
    func oneToOne<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == [Int], S.Event == Int, S.Value == [Int] {
        testPerformance(setupClosure: setupClosure) { (store) in
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
    
    func oneToMany<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == [Int], S.Event == Int, S.Value == [Int] {
        testPerformance(setupClosure: setupClosure) { (store) in
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
    
    func manyToMany<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == [Int], S.Event == Int, S.Value == [Int] {
        testMultiplePerformance(setupClosure: { (0 ..< $0).map { _ in setupClosure() } }) { (stores) in
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
    
    func lockIntensiveOperation<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == [Int], S.Event == Int, S.Value == [Int] {
            testPerformance(setupClosure: setupClosure) { (store) in
                for _ in 0 ..< Const.readMultiplicator {
                    let exp = self.expectation(description: "Wait for store to synchronize")
                    var accumulator: Int = 0
                    store.producer.startWithValues { value in
                        accumulator = accumulator + (store.value.last ?? 0) // Intensionally accessing store.value here to check locking behavior
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
}

// MARK: – Testing pattern for quadratic time. Can be applied to concrete store classes
extension QuadraticTime {
    struct State: Defaultable {
        let data: [StateSlice]; struct StateSlice {
            let data: [Int]
        }
        static func reduce(state: State, action: Int) -> State {
            return State(
                data: [StateSlice(data: [action])] +
                    state.data.map { StateSlice(data: $0.data + [action]) }
            )
        }
        static var defaultValue: State = .init(data: [])
    }
    
    func oneToOne<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == State, S.Event == Int, S.Value == State {
        testPerformance(setupClosure: setupClosure) { (store) in
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
    
    func oneToMany<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == State, S.Event == Int, S.Value == State {
        testPerformance(setupClosure: setupClosure) { (store) in
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
    
    func manyToMany<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == State, S.Event == Int, S.Value == State {
        testMultiplePerformance(timeout: 10, setupClosure: { (0 ..< $0).map { _ in setupClosure() } }) { (stores) in
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
    
    func lockIntensiveOperation<S: StoreProtocol & PropertyProtocol>(_ setupClosure: @escaping () -> S)
        where S.State == State, S.Event == Int, S.Value == State {
            testPerformance(setupClosure: setupClosure) { (store) in
                for _ in 0 ..< Const.readMultiplicator {
                    let exp = self.expectation(description: "Wait for store to synchronize")
                    var accumulator: Int = 0
                    store.producer.startWithValues { value in
                        accumulator = accumulator + (store.value.data.last?.data.last ?? 0) // Intensionally accessing store.value here to check locking behavior
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
}

// MARK: - Concrete test class for eventual consistency store constant time
class ConstantTimeEventualConsistency: ConstantTime, StoreProviderProtocol {
    var store: Store<Int, Int> {
        StoreBuilder<Int, Int, Store<Int, Int>>()
            .reducer({ $0 + $1 })
            .scheduleRead(on: self.readScheduler)
            .build()
    }
    lazy var setupClosure = { return self.store }
    @objc func testOneToOnePerformance() {
        self.oneToOne(self.setupClosure)
    }
    @objc func testOneToManyPerformance() {
        self.oneToMany(self.setupClosure)
    }
    @objc func testManyToManyPerformance() {
        self.manyToMany(self.setupClosure)
    }
    @objc func testLockIntensivePerformance() {
        self.lockIntensiveOperation(self.setupClosure)
    }
}

// MARK: - Concrete test class for strong consistency store constant time
class ConstantTimeStrongConsistency: ConstantTime, StoreProviderProtocol {
    var store: StrongConsistencyStore<Int, Int> {
        StoreBuilder<Int, Int, StrongConsistencyStore<Int, Int>>()
            .reducer({ $0 + $1 })
            .scheduleRead(on: self.readScheduler)
            .build()
    }
    lazy var setupClosure = { return self.store }
    @objc func testOneToOnePerformance() {
        self.oneToOne(self.setupClosure)
    }
    @objc func testOneToManyPerformance() {
        self.oneToMany(self.setupClosure)
    }
    @objc func testManyToManyPerformance() {
        self.manyToMany(self.setupClosure)
    }
    @objc func testLockIntensivePerformance() {
        self.lockIntensiveOperation(self.setupClosure)
    }
}

// MARK: - Concrete test class for eventual consistency store linear time
class LinearTimeEventualConsistency: LinearTime, StoreProviderProtocol {
    var store: Store<[Int], Int> {
        StoreBuilder<[Int], Int, Store<[Int], Int>>(state: [])
            .reducer({ $0 + [$1] })
            .scheduleRead(on: self.readScheduler)
            .build()
    }
    lazy var setupClosure = { return self.store }
    @objc func testOneToOnePerformance() {
        self.oneToOne(self.setupClosure)
    }
    @objc func testOneToManyPerformance() {
        self.oneToMany(self.setupClosure)
    }
    @objc func testManyToManyPerformance() {
        self.manyToMany(self.setupClosure)
    }
    @objc func testLockIntensivePerformance() {
        self.lockIntensiveOperation(self.setupClosure)
    }
}

// MARK: - Concrete test class for strong consistency store linear time
class LinearTimeStrongConsistency: LinearTime, StoreProviderProtocol {
    var store: StrongConsistencyStore<[Int], Int> {
        StoreBuilder<[Int], Int, StrongConsistencyStore<[Int], Int>>(state: [])
            .reducer({ $0 + [$1] })
            .scheduleRead(on: self.readScheduler)
            .build()
    }
    lazy var setupClosure = { return self.store }
    @objc func testOneToOnePerformance() {
        self.oneToOne(self.setupClosure)
    }
    @objc func testOneToManyPerformance() {
        self.oneToMany(self.setupClosure)
    }
    @objc func testManyToManyPerformance() {
        self.manyToMany(self.setupClosure)
    }
    @objc func testLockIntensivePerformance() {
        self.lockIntensiveOperation(self.setupClosure)
    }
}

// MARK: - Concrete test class for eventual consistency store quadratic time
class QuadraticTimeEventualConsistency: QuadraticTime, StoreProviderProtocol {
    var store: Store<State, Int> {
        StoreBuilder<State, Int, Store<State, Int>>()
            .reducer(State.reduce)
            .scheduleRead(on: self.readScheduler)
            .build()
    }
    lazy var setupClosure = { return self.store }
    @objc func testOneToOnePerformance() {
        self.oneToOne(self.setupClosure)
    }
    @objc func testOneToManyPerformance() {
        self.oneToMany(self.setupClosure)
    }
    @objc func testManyToManyPerformance() {
        self.manyToMany(self.setupClosure)
    }
    @objc func testLockIntensivePerformance() {
        self.lockIntensiveOperation(self.setupClosure)
    }
}

// MARK: - Concrete test class for strong consistency store quadratic time
class QuadraticTimeStrongConsistency: QuadraticTime, StoreProviderProtocol {
    var store: StrongConsistencyStore<State, Int> {
        StoreBuilder<State, Int, StrongConsistencyStore<State, Int>>()
            .reducer(State.reduce)
            .scheduleRead(on: self.readScheduler)
            .build()
    }
    lazy var setupClosure = { return self.store }
    @objc func testOneToOnePerformance() {
        self.oneToOne(self.setupClosure)
    }
    @objc func testOneToManyPerformance() {
        self.oneToMany(self.setupClosure)
    }
    @objc func testManyToManyPerformance() {
        self.manyToMany(self.setupClosure)
    }
    @objc func testLockIntensivePerformance() {
        self.lockIntensiveOperation(self.setupClosure)
    }
}
