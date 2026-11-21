import Foundation
import PulseDomain
import SwiftData

/// Sort du magasin synchronisé les valeurs Apple Health écrites avant M8a (spec M8 §5.2), en trois étapes : nuits, séances,
/// mesures. Chaque étape commence par une requête filtrée et ne fait rien si elle revient vide ; sinon elle écrit d'abord le
/// magasin local, puis vide ou supprime côté synchronisé, en un seul `save()`. Une étape qui échoue ne retire rien d'iCloud :
/// elle sera rejouée au passage suivant. Aucun drapeau « déjà fait ».
@ModelActor
public actor SwiftDataHealthDataRelocation: HealthDataRelocating {
    public func relocate() throws -> Bool {
        let nights = try relocateNights()
        let workouts = try relocateWorkouts()
        let measurements = try relocateMeasurements()
        return nights || workouts || measurements
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
        try commit {
            let readings = try modelContext.fetch(FetchDescriptor<StoredRecoveryReading>())
            var readingDays = Set(readings.map(\.day))
            // Les lignes vivantes d'abord : si un jour a aussi une ligne supprimée, ce sont leurs valeurs qui comptent.
            for row in rows.sorted(by: { $0.deletedAt == nil && $1.deletedAt != nil }) {
                if row.deletedAt == nil, !readingDays.contains(row.day) {
                    modelContext.insert(StoredRecoveryReading(day: row.day, from: row.toDomain(), at: row.updatedAt))
                    readingDays.insert(row.day)
                }
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
        try commit {
            var localIDs = Set(try modelContext.fetch(FetchDescriptor<StoredImportedWorkout>()).map(\.id))
            for row in rows {
                if row.deletedAt == nil, !localIDs.contains(row.id) {
                    modelContext.insert(StoredImportedWorkout(row.toDomain()))
                    localIDs.insert(row.id)
                }
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
        try commit {
            var localIDs = Set(try modelContext.fetch(FetchDescriptor<StoredImportedBodyMeasurement>()).map(\.id))
            for row in rows {
                if row.deletedAt == nil, !localIDs.contains(row.id) {
                    modelContext.insert(StoredImportedBodyMeasurement(row.toDomain()))
                    localIDs.insert(row.id)
                }
                modelContext.delete(row)
            }
        }
        return true
    }

    /// Applique `changes` puis enregistre en un seul `save()`. En cas d'erreur, le contexte est remis à l'état enregistré :
    /// rien n'a quitté le magasin synchronisé, et l'étape suivante n'emporte pas une moitié de celle-ci.
    private func commit(_ changes: () throws -> Void) throws {
        do {
            try changes()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
