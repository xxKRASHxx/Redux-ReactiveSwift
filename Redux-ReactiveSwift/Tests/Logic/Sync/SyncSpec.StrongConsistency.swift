import Foundation
import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import Redux_ReactiveSwift

class StrongConsistencySyncSpec: QuickSpec {
  fileprivate typealias Helper = SyncSpecHelpers
  fileprivate var store: StrongConsistencyStore<Helper.AppState, Helper.AppEvent>!
  
  override func spec() {
    
    describe("Testing sync:") {
      
      beforeEach {
        self.store = StoreBuilder<Helper.AppState, Helper.AppEvent, StrongConsistencyStore<Helper.AppState, Helper.AppEvent>>()
          .dispatcher(scheduler: QueueScheduler.main)
          .reducer(Helper.appReducer)
          .build()
      }
      
      it("should not lock while reading an the same queue") {

        let readQueue = DispatchQueue(label: "com.queue.read", qos: .default)

        waitUntil(timeout: 10) { done in
          for i in 1...10000 {

            readQueue.async {
              self.store.consume(event: .some)
            }

            readQueue.async {
              guard i == 10000 else { return }
              done()
            }
          }
        }
      }

      it("Should not lock while reading an the different queues") {

        let readQueue = DispatchQueue(label: "com.queue.read", qos: .default)
        let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)

        waitUntil(timeout: 10) { done in
          for i in 1...10000 {

            writeQueue.async {
              self.store.consume(event: .some)
            }

            readQueue.async {
              guard i == 10000 else { return }
              return done()
            }
          }
        }
      }

      it("Should not lock while reading mapped property") {

        let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)

        waitUntil(timeout: 10) { done in

          self.store
           .map(\.some).producer
           .on { i in
             guard i.int == 10000 else { return }
             return done()
           }
           .start()

          for _ in 1...10000 {
            writeQueue.async {
              self.store.consume(event: .some)
            }
          }
        }
      }
      
      it("Should not lock while reading mapped property async") {

        let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)

        waitUntil(timeout: 10) { done in

          self.store
            .map(\.some.int).producer
            .observe(on: QueueScheduler.main)
            .on { int in
              guard int == 10000 else { return }
              return done() }
            .start()

          for _ in 1...10000 {
            writeQueue.async {
              self.store.consume(event: .some)
            }
          }
        }
      }
      
      it("Should not lock creating new property") {
        
        let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)
        let readQueue = DispatchQueue(label: "com.queue.read", qos: .default)
        
        
        waitUntil(timeout: 10) { done in
          
          let disposable = CompositeDisposable()
          
          readQueue.async {
            for _ in 0...10000 {
              let property = Property(
                initial: self.store.value.some,
                then: self.store.producer.map(\.some))
              
              disposable += property.producer.start()
            }
          }
          
          writeQueue.async {
            for _ in 1...10000 {
              self.store.consume(event: .some)
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
              disposable.dispose()
              done()
            }
          }
        }
      }
        
      it("Should not recursively lock on different queues") {
        
        let writeQueue = DispatchQueue(label: "com.queue.write", qos: .default)
        var count = 0
        waitUntil(timeout: 10) { done in
          writeQueue.async {
            for _ in 1...10000 {
              self.store.consume(event: .some)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              expect(count).toNot(equal(10000))
              done()
            }
          }
          self.store.producer.startWithValues { (state) in
            if self.store.value == state {
              count += 1
            }
          }
        }
      }
      
      it("Should not recursively lock on the same queue") {
        
        var count = 0
        waitUntil(timeout: 10) { done in
          DispatchQueue.main.async {
            for _ in 1...10000 {
              self.store.consume(event: .some)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              expect(count).toNot(equal(10000))
              done()
            }
          }
          self.store.producer.startWithValues { (state) in
            if self.store.value == state {
              count += 1
            }
          }
        }
      }
    }
  }
}
