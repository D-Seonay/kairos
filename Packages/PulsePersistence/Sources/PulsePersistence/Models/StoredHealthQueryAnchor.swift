import Foundation
import PulseDomain
import SwiftData

/// Ancre d'une lecture HealthKit incrémentale (M3), locale seulement.
@Model
public final class StoredHealthQueryAnchor {
    public var kind: String = HealthSampleKind.sdnn.rawValue
    public var anchorData: Data?
    public var updatedAt: Date = Date()

    public init(kind: HealthSampleKind, anchorData: Data?) {
        self.kind = kind.rawValue
        self.anchorData = anchorData
        updatedAt = Date()
    }
}
