import Foundation
import PulseDomain

/// Un déplacement des valeurs Apple Santé qui note ses appels, pour les tests (spec M8 §5.2).
public actor RecordingHealthDataRelocation: HealthDataRelocating {
    public struct Failure: Error {}

    public private(set) var callCount = 0
    private let result: Bool
    private let fails: Bool
    private let onCall: (@Sendable () async -> Void)?

    /// `onCall` s'exécute à chaque appel, avant la réponse : un test y relève l'état du reste du passage à cet instant.
    public init(result: Bool = false, fails: Bool = false, onCall: (@Sendable () async -> Void)? = nil) {
        self.result = result
        self.fails = fails
        self.onCall = onCall
    }

    public func relocate() async throws -> Bool {
        callCount += 1
        await onCall?()
        if fails { throw Failure() }
        return result
    }
}
