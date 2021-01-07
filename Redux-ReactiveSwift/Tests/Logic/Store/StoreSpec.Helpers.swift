//
//  StoreSpec.Helpers.swift
//  CocoaPods-Redux-ReactiveSwift-iOSTests
//
//  Created by Petro Korienev on 5/31/20.
//

import Foundation
import Redux_ReactiveSwift
import ReactiveSwift

extension Int: Defaultable {
    public static var defaultValue: Int {
        return 0
    }
}

// MARK: Helpers

enum IntegerArithmeticAction {
    case increment
    case decrement
    case add(Int)
    case subtract(Int)
}

class StoreSpecHelpers {
    static func createStore<State, Action>(reducer: @escaping (State, Action) -> State,
                                            initialValue: State) -> (Store<State, Action>, CallSpy) {
        let callSpy = CallSpy.makeCallSpy(f2: reducer)
        let store: Store<State,Action> = .init(state: initialValue, reducers: [callSpy.1])
        return (store, callSpy.0)
    }

    static func createStore<State, Action>(reducers first: @escaping (State, Action) -> State,
                                            _ second: @escaping (State, Action) -> State,
                                            initialValue: State) -> (Store<State, Action>, CallSpy, CallSpy) {
        let callSpy1 = CallSpy.makeCallSpy(f2: first)
        let callSpy2 = CallSpy.makeCallSpy(f2: second)

        let store: Store<State,Action> = .init(state: initialValue, reducers: [callSpy1.1, callSpy2.1])
        return (store, callSpy1.0, callSpy2.0)
    }

    static func createStore<State, Action>(reducers: [(State, Action) -> State],
                                            initialValue: State) -> (Store<State, Action>) {
        let store: Store<State,Action> = .init(state: initialValue, reducers: reducers)
        return store
    }

    static func createStrongConsistencyStore<State, Action>(reducer: @escaping (State, Action) -> State,
                                                             initialValue: State) -> (StrongConsistencyStore<State, Action>, CallSpy) {
        let callSpy = CallSpy.makeCallSpy(f2: reducer)
        let store: StrongConsistencyStore<State,Action> = .init(state: initialValue, reducers: [callSpy.1])
        return (store, callSpy.0)
    }

    static func createStrongConsistencyStore<State, Action>(reducers first: @escaping (State, Action) -> State,
                                                             _ second: @escaping (State, Action) -> State,
                                                             initialValue: State) -> (StrongConsistencyStore<State, Action>, CallSpy, CallSpy) {
        let callSpy1 = CallSpy.makeCallSpy(f2: first)
        let callSpy2 = CallSpy.makeCallSpy(f2: second)

        let store: StrongConsistencyStore<State,Action> = .init(state: initialValue, reducers: [callSpy1.1, callSpy2.1])
        return (store, callSpy1.0, callSpy2.0)
    }

    static func createStrongConsistencyStore<State, Action>(reducers: [(State, Action) -> State],
                                                             initialValue: State) -> (StrongConsistencyStore<State, Action>) {
        let store: StrongConsistencyStore<State,Action> = .init(state: initialValue, reducers: reducers)
        return store
    }

    static func observeValues<S: PropertyProtocol, State>(of store: S,
                                                                   with observer: @escaping (State) -> ()) -> CallSpy
        where S.Value == State {
        let callSpy = CallSpy.makeCallSpy(f1: observer)
        store.signal.observeValues(callSpy.1)
        return callSpy.0
    }

    static func observeValuesViaProducer<S: PropertyProtocol, State>(of store: S,
                                                                              with observer: @escaping (State) -> ()) -> CallSpy
        where S.Value == State {
        let callSpy = CallSpy.makeCallSpy(f1: observer)
        store.producer.startWithValues(callSpy.1)
        return callSpy.0
    }

    static func intReducer(state: Int, event: IntegerArithmeticAction) -> Int {
        switch event {
        case .increment: return state + 1;
        case .decrement: return state - 1;
        case .add(let operand): return state + operand;
        case .subtract(let operand): return state - operand;
        }
    }
    static func nsNumberReducer(state: NSNumber, event: IntegerArithmeticAction) -> NSNumber {
        switch event {
        case .increment: return NSNumber(integerLiteral: state.intValue + 1);
        case .decrement: return NSNumber(integerLiteral: state.intValue - 1);
        case .add(let operand): return NSNumber(integerLiteral: state.intValue + operand);
        case .subtract(let operand): return NSNumber(integerLiteral: state.intValue - operand);
        }
    }
    static func stringReducer(state: String, event: IntegerArithmeticAction) -> String {
        switch event {
        case .increment: return state + "1";
        case .decrement: return String(state.dropLast());
        case .add(let operand): return state + (1...operand).map {"\($0)"}.joined(separator: "");
        case .subtract(let operand): return String(state.dropLast(operand));
        }
    }
    static func observeIntValues(values: Int) {}
    static func observeNumberValues(values: NSNumber) {}
}
