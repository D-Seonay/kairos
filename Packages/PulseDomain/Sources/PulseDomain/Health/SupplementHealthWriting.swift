import Foundation

/// Une prise à écrire dans Apple Santé : la quantité est déjà dans l'unité du type (µg, mg ou g, spec M5 §6).
public struct SupplementHealthEntry: Sendable, Equatable {
    public var intakeID: UUID
    public var type: SupplementHealthType
    public var amount: Double
    public var date: Date

    public init(intakeID: UUID, type: SupplementHealthType, amount: Double, date: Date) {
        self.intakeID = intakeID
        self.type = type
        self.amount = amount
        self.date = date
    }
}

/// L'écriture des prises de compléments dans Apple Santé (spec M5 §6), derrière un protocole pour les tests.
public protocol SupplementHealthWriting: Sendable {
    /// L'accès en écriture aux quatre types : autorisé dès qu'un type l'est.
    func supplementWriteAccess() async -> HealthWriteAccess
    /// Montre la demande système si elle n'a jamais été faite, puis rend l'état.
    func requestSupplementWriteAccess() async -> HealthWriteAccess
    /// Écrit la prise et rend l'identifiant Apple Santé de l'échantillon.
    func save(_ entry: SupplementHealthEntry) async throws -> UUID
    /// Supprime l'échantillon écrit par Pulse ; sans effet s'il n'existe plus.
    func deleteSupplementSample(id: UUID) async throws
}

/// Doublure en mémoire : l'accès se règle, les échantillons écrits et supprimés sont gardés.
public actor StubSupplementHealthWriter: SupplementHealthWriting {
    public private(set) var access: HealthWriteAccess
    private let grantedOnRequest: HealthWriteAccess
    public private(set) var requestCount = 0
    public private(set) var saved: [UUID: SupplementHealthEntry] = [:]
    public private(set) var deleted: [UUID] = []
    private var failsOnSave: Bool

    public init(access: HealthWriteAccess = .authorized, grantedOnRequest: HealthWriteAccess = .authorized,
                failsOnSave: Bool = false) {
        self.access = access
        self.grantedOnRequest = grantedOnRequest
        self.failsOnSave = failsOnSave
    }

    /// L'écriture échoue tant que `fails` est vrai, comme sur un iPhone verrouillé.
    public func setFailsOnSave(_ fails: Bool) {
        failsOnSave = fails
    }

    public func supplementWriteAccess() async -> HealthWriteAccess {
        access
    }

    public func requestSupplementWriteAccess() async -> HealthWriteAccess {
        requestCount += 1
        if access == .notDetermined { access = grantedOnRequest }
        return access
    }

    public struct Failure: Error {}

    public func save(_ entry: SupplementHealthEntry) async throws -> UUID {
        if failsOnSave { throw Failure() }
        let id = UUID()
        saved[id] = entry
        return id
    }

    public func deleteSupplementSample(id: UUID) async throws {
        saved[id] = nil
        deleted.append(id)
    }
}
