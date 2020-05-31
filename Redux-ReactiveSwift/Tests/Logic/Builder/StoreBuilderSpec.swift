//
//  StoreBuilderSpec.swift
//  Redux-ReactiveSwift
//
//  Created by Petro Korienev on 1/1/18.
//

import Quick
import Nimble
import ReactiveSwift
import Redux_ReactiveSwift

class StoreBuilderSpec: QuickSpec {
    override func spec() {
        struct AppState: Defaultable { let some: String; static var defaultValue = AppState(some: "default")}
        enum AppEvent { case some }
        func appReducer(state: AppState, event: AppEvent) -> AppState { return state }

        describe("Core concepts") {
            it("should pass initialization with state") {
                let s = StoreBuilder<AppState, AppEvent, Store<AppState, AppEvent>>
                    .init(state: AppState(some: "s"))
                    .build()
                expect(s.value.some) == "s"
            }
            it("should pass defaultable initialization") {
                let s = StoreBuilder<AppState, AppEvent, Store<AppState, AppEvent>>()
                    .build()
                expect(s.value.some) == "default"
            }
        }

        describe("DSL tests") {

        }
    }
}
