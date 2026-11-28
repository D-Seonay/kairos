import Foundation
import PulseDomain

/// Écrit dans Apple Santé les séances Pulse terminées, en direct ou saisies après coup, et supprime l'entraînement d'une séance
/// supprimée (spec M4 §19.5). Les séances importées de Hevy et les séances abandonnées ne sont jamais écrites **(choix du
/// constructeur)**. Une écriture ratée ne retient jamais la séance : elle reste dans Pulse sans entraînement Apple Santé.
public final class HealthWorkoutExporter: Sendable {
    /// L'équivalent métabolique retenu pour la musculation.
    static let strengthMET = 5.0

    private let writer: any WorkoutHealthWriting
    private let workouts: any WorkoutRepository
    private let profiles: any ProfileRepository
    /// Les pesées, Apple Santé comprise : le profil n'en porte plus la valeur (spec M8 §5.3).
    private let measurements: any BodyMeasurementRepository
    private let calendar: Calendar

    public init(writer: any WorkoutHealthWriting, workouts: any WorkoutRepository, profiles: any ProfileRepository,
                measurements: any BodyMeasurementRepository, calendar: Calendar) {
        self.writer = writer
        self.workouts = workouts
        self.profiles = profiles
        self.measurements = measurements
        self.calendar = calendar
    }

    public func access() async -> HealthWriteAccess {
        await writer.writeAccess()
    }

    /// La demande système, après l'écran d'explication.
    public func requestAccess() async -> HealthWriteAccess {
        await writer.requestWriteAccess()
    }

    /// Écrit l'entraînement de la séance si elle s'y prête et si l'écriture est permise, enregistre son identifiant Apple Santé
    /// dans la séance, et rend la séance relue. Sinon, ou en cas d'échec, rend la séance telle quelle.
    public func export(_ session: WorkoutSession) async -> WorkoutSession {
        guard Self.isExportable(session), let endedAt = session.endedAt, await writer.writeAccess() == .authorized else {
            return session
        }
        let weightKg = await ProfileWeightSync.currentWeight(measurements: measurements, profiles: profiles, now: endedAt,
                                                             calendar: calendar)
        let entry = StrengthWorkoutEntry(sessionID: session.id, start: session.startedAt, end: endedAt,
                                         energyKcal: Self.energyKcal(weightKg: weightKg, from: session.startedAt, to: endedAt))
        let id: UUID
        do {
            id = try await writer.save(entry)
        } catch {
            logger.failure("Séance non écrite dans Apple Santé", error)
            return session
        }
        var written = session
        written.healthKitUUID = id.uuidString
        do {
            try await workouts.save(written)
        } catch {
            // Sans identifiant enregistré, l'entraînement ne pourrait plus être supprimé avec la séance : on le retire.
            logger.failure("Identifiant Apple Santé de la séance non enregistré", error)
            await removeWorkout(id: id)
            return session
        }
        do {
            return try await workouts.session(id: session.id) ?? written
        } catch {
            logger.failure("Séance écrite non relue", error)
            return written
        }
    }

    /// Supprime l'entraînement Apple Santé de la séance, s'il y en a un. Un échec est ignoré : la séance reste supprimée.
    public func removeWorkout(of session: WorkoutSession) async {
        guard let id = session.healthKitUUID.flatMap(UUID.init(uuidString:)) else { return }
        await removeWorkout(id: id)
    }

    private func removeWorkout(id: UUID) async {
        do {
            try await writer.deleteWorkout(id: id)
        } catch {
            logger.failure("Entraînement Apple Santé non supprimé", error)
        }
    }

    /// Une séance Pulse terminée, avec une fin, pas encore écrite.
    static func isExportable(_ session: WorkoutSession) -> Bool {
        session.source == .pulse && session.status == .completed && session.kind == .strength && session.endedAt != nil
            && session.healthKitUUID == nil
    }

    /// 5 MET × poids × durée en heures ; `nil` sans poids.
    static func energyKcal(weightKg: Double?, from start: Date, to end: Date) -> Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return strengthMET * weightKg * max(0, end.timeIntervalSince(start)) / 3_600
    }
}
