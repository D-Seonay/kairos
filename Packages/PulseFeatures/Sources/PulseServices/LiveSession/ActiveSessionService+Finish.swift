import Foundation
import PulseDomain

/// La fin de la séance (spec M4 §14.6, §16, §17) : le récap, l'enregistrement de la `WorkoutSession`, l'abandon, la séance
/// oubliée et le ménage après une suppression totale. Chaque méthode tient dans une seule opération de la file et n'appelle
/// que les aides internes : `current()`, `apply(_:)` ou `start(_:)`, qui passent par la file, l'attendraient sans fin.
extension ActiveSessionService {
    /// Au-delà de cet écart entre la dernière action et maintenant, la séance est tenue pour oubliée.
    static let forgottenAfter: TimeInterval = 3 * 3_600

    /// Pour une séance laissée ouverte plus de 3 h sans action, l'heure de fin proposée : la dernière série validée plus son
    /// repos. `nil` sinon, sans séance lisible ou sans série validée.
    public func suggestedEnd() async -> Date? {
        let suggested = try? await queue.run { () async throws -> Date? in
            guard let session = try await self.loadSession(),
                  self.now().timeIntervalSince(session.lastActionAt) > Self.forgottenAfter else { return nil }
            return session.lastValidatedSetEnd
        }
        return suggested ?? nil
    }

    /// Le bilan de la séance si elle finissait à `endedAt`.
    public func recap(endedAt: Date) async throws -> SessionRecap {
        try await queue.run {
            guard let session = try await self.loadSession() else { throw ActiveSessionError.noSession }
            let draft = session.workoutSession(status: .completed, endedAt: endedAt, overallRPE: nil, note: nil,
                                               savedAt: self.now())
            // Une séance déjà écrite par un `finish` dont la suite a échoué ne compte pas deux fois.
            let history = try await self.workouts.sessions(from: .distantPast, to: .distantFuture).filter { $0.id != session.id }
            let directory = ExerciseDirectory(library: self.library,
                                              userExercises: try await self.userExercises.all(includeArchived: true))
            // Le genre de charge de la séance en cours prime : il a été lu à l'ajout de l'exercice.
            let loadKinds = Dictionary(session.exercises.map { ($0.exercise, $0.loadKind) }, uniquingKeysWith: { first, _ in first })
            let load = LoadHistory(sessions: history, onboardingCompletedAt: (try? await self.profiles.load())?.onboardingCompletedAt,
                                   endedAt: endedAt, calendar: self.calendar)
            return SessionRecap.make(draft: draft, history: history, directory: directory,
                                     loadKind: { loadKinds[$0] ?? directory.loadKind(of: $0) }, load: load)
        }
    }

    /// Enregistre la séance terminée avec ses seules séries validées, recalcule les records, efface le snapshot, termine la
    /// Live Activity et annule la notification de repos. La `WorkoutSession` garde l'identifiant de la séance en cours : si
    /// l'écriture échoue, l'erreur remonte, le snapshot reste, et un nouvel appel réécrit la même séance sans doublon.
    public func finish(overallRPE: Int, note: String?, endedAt: Date) async throws -> WorkoutSession {
        try await queue.run {
            guard let session = try await self.loadSession() else { throw ActiveSessionError.noSession }
            let saved = try await self.write(session.workoutSession(status: .completed, endedAt: endedAt,
                                                                     overallRPE: overallRPE, note: note, savedAt: self.now()))
            try await self.clearSession()
            return saved
        }
    }

    /// Enregistre la séance abandonnée avec ses séries validées, sans RPE, puis fait le même ménage que `finish`. Sans série
    /// validée, rien n'est enregistré. Un snapshot illisible est effacé de même : la séance rendue n'a alors aucune série.
    public func abandon(endedAt: Date) async throws -> WorkoutSession {
        try await queue.run {
            guard let snapshot = try await self.store.load() else { throw ActiveSessionError.noSession }
            guard let session = LiveSession.decode(snapshot.payload) else {
                try await self.store.clear()
                await self.activity.endAll(except: nil)
                await self.restNotifier.cancelRestEnd()
                return WorkoutSession(id: snapshot.id, startedAt: snapshot.startedAt, endedAt: endedAt, kind: .strength,
                                      source: .pulse, status: .abandoned, title: "", createdAt: self.now(), updatedAt: self.now())
            }
            var abandoned = session.workoutSession(status: .abandoned, endedAt: endedAt, overallRPE: nil, note: nil,
                                                   savedAt: self.now())
            if !abandoned.sets.isEmpty { abandoned = try await self.write(abandoned) }
            try await self.clearSession()
            return abandoned
        }
    }

    /// Après une suppression totale : efface le snapshot s'il en reste un, termine toutes les Live Activities de séance et
    /// annule la notification de repos, sans rien enregistrer.
    public func discardAfterErase() async {
        _ = try? await queue.run {
            try? await self.store.clear()
            await self.activity.endAll(except: nil)
            await self.restNotifier.cancelRestEnd()
        }
    }

    /// Écrit la séance, puis recalcule les records. Rend la séance relue, avec ses marques de record.
    private func write(_ session: WorkoutSession) async throws -> WorkoutSession {
        try await workouts.save(session)
        // Un recalcul raté ne retient pas la séance : le prochain recalcul (import, suppression, séance) posera les marques.
        _ = try? await records.recomputeAll()
        return (try? await workouts.session(id: session.id)) ?? session
    }

    /// Efface le snapshot, termine la Live Activity et annule la notification de repos.
    private func clearSession() async throws {
        try await store.clear()
        await activity.end()
        await restNotifier.cancelRestEnd()
    }
}

extension LiveSession {
    /// La fin du repos de la dernière série validée : 60 s pour un échauffement, le repos de l'exercice sinon.
    var lastValidatedSetEnd: Date? {
        let validated = exercises.flatMap { exercise in
            exercise.sets.compactMap { set in
                set.completedAt.map { completedAt in
                    completedAt.addingTimeInterval(set.setType == .warmup
                        ? ActiveSessionService.warmUpRestSeconds : TimeInterval(exercise.restSeconds))
                }
            }
        }
        return validated.max()
    }

    /// La séance telle qu'elle s'enregistre : séries validées seulement, numérotées de 0 à n − 1 dans l'ordre de la séance,
    /// avec la proposition pour prévu et la saisie pour réalisé ; durée arrondie à la minute.
    func workoutSession(status: SessionStatus, endedAt: Date, overallRPE: Int?, note: String?, savedAt: Date) -> WorkoutSession {
        var sets: [WorkoutSet] = []
        for exercise in exercises {
            for set in exercise.sets where set.completedAt != nil {
                sets.append(WorkoutSet(
                    id: set.id, order: sets.count, exercise: exercise.exercise, exerciseName: exercise.name, setType: set.setType,
                    supersetGroup: exercise.supersetGroup, plannedWeightKg: set.proposed.weightKg, plannedReps: set.proposed.reps,
                    actualWeightKg: set.weightKg, actualReps: set.reps, durationSeconds: set.durationSeconds, rpe: set.rpe,
                    restSeconds: exercise.restSeconds, completedAt: set.completedAt))
            }
        }
        let notes = exercises.compactMap { exercise in
            exercise.note.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
                .map { ExerciseNote(exercise: exercise.exercise, text: $0) }
        }
        let minutes = (max(0, endedAt.timeIntervalSince(startedAt)) / 60).rounded()
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkoutSession(
            id: id, startedAt: startedAt, endedAt: endedAt, kind: .strength, source: .pulse, status: status, programID: programID,
            routineDayID: routineDayID, title: title, appliedAdjustments: appliedAdjustments,
            refusedAdjustments: refusedAdjustments, overallRPE: overallRPE.map(Double.init),
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil, tonnageKg: tonnageKg, durationMinutes: minutes,
            exerciseNotes: notes, sets: sets, createdAt: savedAt, updatedAt: savedAt)
    }
}
