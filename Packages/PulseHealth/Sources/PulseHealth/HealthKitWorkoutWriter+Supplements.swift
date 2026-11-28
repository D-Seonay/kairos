import Foundation
import HealthKit
import PulseDomain

/// L'écriture des prises de compléments (spec M5 §6) : un échantillon de vitamine D, magnésium, caféine ou protéines par prise,
/// avec l'identifiant de la prise en métadonnée.
extension HealthKitWorkoutWriter: SupplementHealthWriting {
    /// Les types de compléments que Pulse écrit.
    static var supplementTypes: Set<HKQuantityType> {
        Set(SupplementHealthType.allCases.map(quantityType))
    }

    static func quantityType(_ type: SupplementHealthType) -> HKQuantityType {
        switch type {
        case .vitaminD: HKQuantityType(.dietaryVitaminD)
        case .magnesium: HKQuantityType(.dietaryMagnesium)
        case .caffeine: HKQuantityType(.dietaryCaffeine)
        case .protein: HKQuantityType(.dietaryProtein)
        }
    }

    static func unit(_ type: SupplementHealthType) -> HKUnit {
        switch type {
        case .vitaminD: .gramUnit(with: .micro)
        case .magnesium, .caffeine: .gramUnit(with: .milli)
        case .protein: .gram()
        }
    }

    public func supplementWriteAccess() async -> HealthWriteAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let statuses = Self.supplementTypes.map { store.authorizationStatus(for: $0) }
        if statuses.contains(.sharingAuthorized) { return .authorized }
        if statuses.contains(.notDetermined) { return .notDetermined }
        return .denied
    }

    public func requestSupplementWriteAccess() async -> HealthWriteAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            try await store.requestAuthorization(toShare: Self.supplementTypes, read: [])
        } catch {
            logger.failure("Demande d'écriture des compléments en échec", error)
        }
        return await supplementWriteAccess()
    }

    public func save(_ entry: SupplementHealthEntry) async throws -> UUID {
        let sample = HKQuantitySample(type: Self.quantityType(entry.type),
                                      quantity: HKQuantity(unit: Self.unit(entry.type), doubleValue: entry.amount),
                                      start: entry.date, end: entry.date,
                                      metadata: [HKMetadataKeyExternalUUID: entry.intakeID.uuidString])
        try await store.save(sample)
        return sample.uuid
    }

    public func deleteSupplementSample(id: UUID) async throws {
        let ownSample = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObject(with: id), HKQuery.predicateForObjects(from: HKSource.default())
        ])
        for type in Self.supplementTypes where store.authorizationStatus(for: type) == .sharingAuthorized {
            try await deleteObjects(of: type, matching: ownSample)
        }
    }

    /// Les échantillons de compléments écrits par Pulse, pour la suppression totale.
    func deleteAllSupplementSamples() async throws {
        let fromPulse = HKQuery.predicateForObjects(from: HKSource.default())
        for type in Self.supplementTypes where store.authorizationStatus(for: type) == .sharingAuthorized {
            try await deleteObjects(of: type, matching: fromPulse)
        }
    }
}
