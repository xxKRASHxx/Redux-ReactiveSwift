//
//  SyncSpec.Helpers.swift
//  CocoaPods-Redux-ReactiveSwift-iOSTests
//
//  Created by Petro Korienev on 6/1/20.
//

import Foundation
import Redux_ReactiveSwift

class SyncSpecHelpers {
  struct AppState: Defaultable, Equatable {
    let some: SomeState; struct SomeState: Equatable {
      let int: Int
    }
    static var defaultValue = AppState(some: .init(int: 0))
  }
  
  enum AppEvent {
    case some
  }
  
  static func appReducer(state: AppState, event: AppEvent) -> AppState {
    .init(
      some: .init(int: state.some.int + 1)
    )
  }
}
