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

class BasePerformanceTest: XCTestCase {
    var writeQueue: DispatchQueue!
    var readQueue: DispatchQueue!
    
    override func setUp() {
        writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)
        readQueue = DispatchQueue(label: "com.queue.read", qos: .default)
    }
    
    override class var defaultPerformanceMetrics: [XCTPerformanceMetric] {
        return [
            .wallClockTime,
            .runTime,
            .systemTime,
            .userTime,
            .totalHeapKB
        ]
    }
}

class ConstantTime: BasePerformanceTest {
    @objc func testOneToOnePerformanceExample() {
        measure {
            let exp = self.expectation(description: "Wait for store to synchronize")
            let store = Store<Int, Int>(
                reducers: [{ $0 + $1 }],
                readScheduler: QueueScheduler.init(qos: .default,
                                                   name: "",
                                                   targeting: readQueue)
            )
            store.producer.startWithValues { (value) in
                if value == 500500 { exp.fulfill() }
            }
            writeQueue.async {
                for i in 0...1000 {
                    store.consume(event: i)
                }
            }
            self.waitForExpectations(timeout: 5) { error in
                self.stopMeasuring()
                if let error = error { print(error) }
            }
        }
    }
}

class LinearTime: BasePerformanceTest {
    @objc func testOneToOnePerformanceExample() {
        measure {
            let exp = self.expectation(description: "Wait for store to synchronize")
            let store = Store<[Int], Int>(
                state: [],
                reducers: [{ $0 + [$1] }],
                readScheduler: QueueScheduler.init(qos: .default,
                                                   name: "",
                                                   targeting: readQueue)
            )
            store.producer.startWithValues { (value) in
                if value.count == 1000 { exp.fulfill() }
            }
            writeQueue.async {
                for i in 0...1000 {
                    store.consume(event: i)
                }
            }
            self.waitForExpectations(timeout: 5) { error in
                self.stopMeasuring()
                if let error = error { print(error) }
            }
        }
    }
}

class LinearLogarithmicTime: BasePerformanceTest {
    @objc func testOneToOnePerformanceExample() {
        measure {
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
            let exp = self.expectation(description: "Wait for store to synchronize")
            let store = Store<State, Int>(
                state: State(data: []),
                reducers: [State.reduce],
                readScheduler: QueueScheduler.init(qos: .default,
                                                   name: "",
                                                   targeting: readQueue)
            )
            store.producer.startWithValues { (value) in
                if value.data.count == 1000 { exp.fulfill() }
            }
            writeQueue.async {
                for i in 0...1000 {
                    store.consume(event: i)
                }
            }
            self.waitForExpectations(timeout: 5) { error in
                self.stopMeasuring()
                if let error = error { print(error) }
            }
        }
    }
}
