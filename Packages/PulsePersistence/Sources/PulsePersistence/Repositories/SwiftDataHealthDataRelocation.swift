import Foundation
import PulseDomain
import SwiftData

/// Sort du magasin synchronisé les valeurs Apple Health écrites avant M8a (spec M8 §5.2), en trois étapes : nuits, séances,
/// mesures. Chaque étape commence par une requête filtrée et ne fait rien si elle revient vide. Sinon elle avance en deux
/// temps, car un `save()` n'est pas garanti atomique entre les deux fichiers SQLite : d'abord les copies locales, enregistrées ;
/// ensuite seulement le retrait côté synchronisé, enregistré à part. Si ce second temps échoue, il est annulé et rien n'a quitté
/// iCloud ; au passage suivant, le jour ou l'identifiant est déjà en local et l'étape ne fait plus que vider ou supprimer.
/// Aucun drapeau « déjà fait ».
@ModelActor
public actor SwiftDataHealthDataRelocation: HealthDataRelocating {
    /// Pour les tests : erreur levée juste avant d'enregistrer le retrait côté synchronisé.
    private var syncedPhaseFailure: (any Error)?

    func failSyncedPhase(with error: (any Error)?) { syncedPhaseFailure = error }

    /// Les trois étapes sont indépendantes : chacune est tentée même si une précédente a échoué, puis la première erreur est
    /// relancée. Sans erreur, rend vrai si une étape a déplacé quelque chose.
    public func relocate() throws -> Bool {
        let results = [Result { try relocateNights() }, Result { try relocateWorkouts() }, Result { try relocateMeasurements() }]
        for case .failure(let error) in results {
            throw error
        }
        // swiftlint:disable:next silent_try - les échecs ont été relancés juste avant
        return results.contains { (try? $0.get()) == true }
    }

    /// Les valeurs brutes passent dans la lecture locale du jour ; une lecture déjà présente l'emporte, elle est plus récente.
    /// Les champs synchronisés sont vidés dans tous les cas, sans toucher à `updatedAt`. Une ligne supprimée logiquement
    /// n'est plus lisible : ses valeurs sont vidées sans être recopiées, comme pour les séances.
    private func relocateNights() throws -> Bool {
        let withRawValue = #Predicate<StoredDailyRecovery> { (row: StoredDailyRecovery) -> Bool in
            (row.sdnnMs != nil || row.sdnnBaselineMs != nil) || (row.restingHeartRate != nil || row.restingHeartRateBaseline != nil)
                || (row.asleepMinutes != nil || row.deepMinutes != nil)
        }
        let rows = try modelContext.fetch(FetchDescriptor<StoredDailyRecovery>(predicate: withRawValue))
        guard !rows.isEmpty else { return false }
        try commitLocalCopies {
            var readingDays = Set(try modelContext.fetch(FetchDescriptor<StoredRecoveryReading>()).map(\.day))
            // Deux appareils peuvent avoir créé chacun une ligne pour le même jour : seule la première vue d'un jour est recopiée,
            // donc les lignes vivantes passent d'abord, de la plus récente à la plus ancienne, pour que la dernière écriture gagne.
            // Les lignes supprimées logiquement ne sont jamais recopiées.
            let alive = rows.filter { $0.deletedAt == nil }.sorted { $0.updatedAt > $1.updatedAt }
            for row in alive where !readingDays.contains(row.day) {
                let reading = StoredRecoveryReading(day: row.day, from: row.toDomain(), at: row.updatedAt)
                guard !reading.isEmpty else { continue }
                modelContext.insert(reading)
                readingDays.insert(row.day)
            }
        }
        try commitSyncedRemoval {
            for row in rows {
                row.clearHealthValues()
            }
        }
        return true
    }

    /// Une course vivante est copiée en local si son identifiant n'y est pas déjà ; puis toutes les lignes Apple Santé sont
    /// supprimées pour de vrai, y compris celles marquées supprimées (une suppression logique laisse les valeurs dans iCloud).
    private func relocateWorkouts() throws -> Bool {
        let health = SessionSource.appleHealth.rawValue
        let rows = try modelContext.fetch(FetchDescriptor<StoredWorkoutSession>(predicate: #Predicate { $0.source == health }))
        guard !rows.isEmpty else { return false }
        try commitLocalCopies {
            var localIDs = Set(try modelContext.fetch(FetchDescriptor<StoredImportedWorkout>()).map(\.id))
            for row in rows where row.deletedAt == nil && !localIDs.contains(row.id) {
                modelContext.insert(StoredImportedWorkout(row.toDomain()))
                localIDs.insert(row.id)
            }
        }
        try commitSyncedRemoval {
            for row in rows {
                modelContext.delete(row)
            }
        }
        return true
    }

    /// Même traitement que les séances, pour les pesées Apple Santé.
    private func relocateMeasurements() throws -> Bool {
        let health = MeasurementSource.appleHealth.rawValue
        let rows = try modelContext.fetch(FetchDescriptor<StoredBodyMeasurement>(predicate: #Predicate { $0.source == health }))
        guard !rows.isEmpty else { return false }
        try commitLocalCopies {
            var localIDs = Set(try modelContext.fetch(FetchDescriptor<StoredImportedBodyMeasurement>()).map(\.id))
            for row in rows where row.deletedAt == nil && !localIDs.contains(row.id) {
                modelContext.insert(StoredImportedBodyMeasurement(row.toDomain()))
                localIDs.insert(row.id)
            }
        }
        try commitSyncedRemoval {
            for row in rows {
                modelContext.delete(row)
            }
        }
        return true
    }

    /// Premier temps : écrit les copies locales et les enregistre, s'il y en a.
    private func commitLocalCopies(_ changes: () throws -> Void) throws {
        try commit(changes)
    }

    /// Second temps : vide ou supprime côté synchronisé et l'enregistre à part, une fois les copies locales enregistrées.
    private func commitSyncedRemoval(_ changes: () throws -> Void) throws {
        try commit {
            try changes()
            if let syncedPhaseFailure { throw syncedPhaseFailure }
        }
    }

    /// Applique `changes` puis enregistre s'il y a quelque chose à enregistrer. En cas d'erreur, le contexte est remis à l'état
    /// enregistré : ce temps est annulé en entier, et l'étape suivante n'en emporte pas une moitié.
    private func commit(_ changes: () throws -> Void) throws {
        do {
            try changes()
            if modelContext.hasChanges { try modelContext.save() }
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
