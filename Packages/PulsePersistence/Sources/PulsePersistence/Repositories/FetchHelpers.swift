import Foundation
import SwiftData

extension ModelContext {
    /// Premier enregistrement qui satisfait le prédicat, ou nil.
    func first<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }
}
