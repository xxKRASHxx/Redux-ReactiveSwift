import Foundation

extension DispatchQueue {
    private struct Const {
        static let rSyncKey = DispatchSpecificKey<NSString>()
    }
    var recursiveSyncEnabled: Bool {
        set { self.setSpecific(key: Const.rSyncKey, value: newValue ? (label as NSString) : nil)}
        get { self.getSpecific(key: Const.rSyncKey) != nil }
    }
    func recursiveSync<T>(_ closure: () -> T) -> T {
        let specific = DispatchQueue.getSpecific(key: Const.rSyncKey)
        return (specific != nil && specific == self.getSpecific(key: Const.rSyncKey)) ?
            closure() :
            sync(execute: closure)
    }
}
