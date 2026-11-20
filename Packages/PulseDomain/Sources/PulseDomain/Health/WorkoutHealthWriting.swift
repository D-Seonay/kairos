import Foundation

/// Ce que Pulse a le droit d'écrire dans Apple Santé. Contrairement à la lecture, l'état de l'écriture est connu.
public enum HealthWriteAccess: Sendable, Equatable {
    /// Jamais demandé : la première séance enregistrée montre l'écran d'explication (spec M4 §19.5).
    case notDetermined
    case authorized
    case denied
    /// Pas d'Apple Santé sur l'appareil, ou pas d'écriture branchée (tests, aperçus).
    case unavailable
}

/// Un entraînement de musculation à écrire dans Apple Santé : la séance, son début, sa fin et son énergie estimée.
public struct StrengthWorkoutEntry: Sendable, Equatable {
    public var sessionID: UUID
    public var start: Date
    public var end: Date
    /// En kilocalories ; `nil` sans poids connu, l'énergie est alors omise.
    public var energyKcal: Double?

    public init(sessionID: UUID, start: Date, end: Date, energyKcal: Double?) {
        self.sessionID = sessionID
        self.start = start
        self.end = end
        self.energyKcal = energyKcal
    }
}

/// L'écriture des séances dans Apple Santé (spec M4 §19.5), derrière un protocole pour les tests.
public protocol WorkoutHealthWriting: Sendable {
    func writeAccess() async -> HealthWriteAccess
    /// Montre la demande système si elle n'a jamais été faite, puis rend l'état.
    func requestWriteAccess() async -> HealthWriteAccess
    /// Écrit l'entraînement et rend son identifiant Apple Santé.
    func save(_ entry: StrengthWorkoutEntry) async throws -> UUID
    /// Supprime l'entraînement écrit par Pulse, et son énergie ; sans effet s'il n'existe plus.
    func deleteWorkout(id: UUID) async throws
}

/// Doublure en mémoire : l'accès se règle, les entraînements écrits et supprimés sont gardés.
public actor StubWorkoutHealthWriter: WorkoutHealthWriting {
    public private(set) var access: HealthWriteAccess
    /// L'accès que donne la demande système.
    private let grantedOnRequest: HealthWriteAccess
    public private(set) var requestCount = 0
    public private(set) var saved: [UUID: StrengthWorkoutEntry] = [:]
    public private(set) var deleted: [UUID] = []
    private let failsOnSave: Bool

    public init(access: HealthWriteAccess = .authorized, grantedOnRequest: HealthWriteAccess = .authorized,
                failsOnSave: Bool = false) {
        self.access = access
        self.grantedOnRequest = grantedOnRequest
        self.failsOnSave = failsOnSave
    }

    public func writeAccess() async -> HealthWriteAccess {
        access
    }

    public func requestWriteAccess() async -> HealthWriteAccess {
        requestCount += 1
        if access == .notDetermined { access = grantedOnRequest }
        return access
    }

    public struct Failure: Error {}

    public func save(_ entry: StrengthWorkoutEntry) async throws -> UUID {
        if failsOnSave { throw Failure() }
        let id = UUID()
        saved[id] = entry
        return id
    }

    public func deleteWorkout(id: UUID) async throws {
        saved[id] = nil
        deleted.append(id)
    }
}
