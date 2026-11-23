import Foundation
import SwiftData

/// La FC moyenne et le RPE estimé d'une course Pulse, gardés dans le magasin local : la ligne synchronisée de la séance
/// les porte à `nil` (frontière M8). Une ligne par séance : `sessionID` est une clé unique (le magasin local n'est pas
/// soumis aux règles de CloudKit).
@Model
public final class StoredRunHealthSummary {
    @Attribute(.unique) public var sessionID: UUID = UUID()
    public var averageHeartRate: Double?
    public var estimatedRPE: Double?

    public init(sessionID: UUID, averageHeartRate: Double?, estimatedRPE: Double?) {
        self.sessionID = sessionID
        self.averageHeartRate = averageHeartRate
        self.estimatedRPE = estimatedRPE
    }
}
