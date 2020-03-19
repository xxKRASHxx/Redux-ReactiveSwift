import Foundation
import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Redux_ReactiveSwift

extension SyncSpec {
  struct AppState: Defaultable {
    let some: SomeState; struct SomeState {
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

class SyncSpec: QuickSpec {
  
  var store: Store<AppState, AppEvent>!
  
  override func spec() {
    
    describe("Testing sync:") {
      
      beforeEach {
        
        let readQueue = DispatchQueue(label: "com.queue.read", qos: .default)
        
        let scheduler = QueueScheduler(
          qos: .default,
          name: "com.scheduler.read",
          targeting: readQueue)
        self.store = StoreBuilder<AppState, AppEvent, Store<AppState, AppEvent>>()
          .dispatcher(scheduler: QueueScheduler.main)
          .reducer(SyncSpec.appReducer)
          .build()
      }
      
      //            it("should not lock while reading an the same queue") {
      //
      //              let readQueue = DispatchQueue(label: "com.queue.read", qos: .default)
      //
      //              waitUntil(timeout: 10) { done in
      //                for i in 1...10000 {
      //
      //                  readQueue.async {
      //                    self.store.consume(event: .some)
      //                  }
      //
      //                  readQueue.async {
      //                    guard i == 10000 else { return }
      //                    done()
      //                  }
      //                }
      //              }
      //            }
      //
      //            it("Should not lock while reading an the different queues") {
      //
      //              let readQueue = DispatchQueue(label: "com.queue.read", qos: .default)
      //              let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)
      //
      //              waitUntil(timeout: 10) { done in
      //                for i in 1...10000 {
      //
      //                  writeQueue.async {
      //                    self.store.consume(event: .some)
      //                  }
      //
      //                  readQueue.async {
      //                    guard i == 10000 else { return }
      //                    return done()
      //                  }
      //                }
      //              }
      //            }
      //
      //            it("Should not lock while reading mapped property") {
      //
      //              let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)
      //
      //              waitUntil(timeout: 10) { done in
      //
      //                self.store
      //                 .map(\.some).producer
      //                 .on { i in
      //                   guard i.int == 10000 else { return }
      //                   return done()
      //                 }
      //                 .start()
      //
      //                for _ in 1...10000 {
      //                  writeQueue.async {
      //                    self.store.consume(event: .some)
      //                  }
      //                }
      //              }
      //            }
      
//      it("Should not lock while reading mapped property async") {
//
//        let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)
//
//        waitUntil(timeout: 10) { done in
//
//          self.store
//            .map(\.some.int).producer
//            .observe(on: QueueScheduler.main)
//            .on { int in
//              print(self.store.value)
//              guard int == 10000 else { return }
//              return done() }
//            .start()
//
//          for _ in 1...10000 {
//            writeQueue.async {
//              self.store.consume(event: .some)
//            }
//          }
//        }
//      }
      
      it("Should not lock creating new property") {
        
        let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)
        let readQueue = DispatchQueue(label: "com.queue.read", qos: .default)
        
        
        waitUntil(timeout: 10) { done in
          
          readQueue.async {
            
            for _ in 0...10000 {
              let property = Property(
                initial: self.store.value.some,
                then: self.store.producer.map(\.some))
              
              property.producer.start()
            }
            
            done()
          }
          
          writeQueue.async {
            for _ in 1...10000 {
              self.store.consume(event: .some)
            }
          }
        }
      }
    }
  }
}
