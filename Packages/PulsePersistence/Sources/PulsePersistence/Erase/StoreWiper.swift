import Foundation
import SwiftData

/// Suppression physique de tous les enregistrements, synchronisés puis locaux. Le miroir CloudKit propage les suppressions.
@ModelActor
actor StoreWiper {
    func wipeAll() throws {
        try modelContext.delete(model: StoredProfile.self)
        try modelContext.delete(model: StoredProgram.self)
        try modelContext.delete(model: StoredRoutineDay.self)
        try modelContext.delete(model: StoredRoutineExercise.self)
        try modelContext.delete(model: StoredUserExercise.self)
        try modelContext.delete(model: StoredWorkoutSession.self)
        try modelContext.delete(model: StoredWorkoutSet.self)
        try modelContext.delete(model: StoredScheduledDay.self)
        try modelContext.delete(model: StoredDailyRecovery.self)
        try modelContext.delete(model: StoredCheckIn.self)
        try modelContext.delete(model: StoredSupplement.self)
        try modelContext.delete(model: StoredSupplementIntake.self)
        try modelContext.delete(model: StoredBodyMeasurement.self)
        try modelContext.delete(model: StoredPersonalRecord.self)
        try modelContext.delete(model: StoredCachedHealthSample.self)
        try modelContext.delete(model: StoredHealthQueryAnchor.self)
        try modelContext.delete(model: StoredActiveSessionSnapshot.self)
        try modelContext.save()
    }
}
