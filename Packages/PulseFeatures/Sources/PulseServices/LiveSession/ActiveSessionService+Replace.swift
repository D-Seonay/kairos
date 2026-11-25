import Foundation
import PulseDomain

/// Une alternative proposée au remplacement : l'exercice et le remplaçant déjà planifié, avec sa charge proposée.
public struct ReplacementOption: Sendable, Identifiable {
    public let info: ExerciseInfo
    public let exercise: LiveExercise
    public var id: ExerciseReference { info.reference }

    public init(info: ExerciseInfo, exercise: LiveExercise) {
        self.info = info
        self.exercise = exercise
    }
}

extension ActiveSessionService {
    /// Les alternatives à l'exercice `exerciseID` de la séance en cours (spec M4 §19.3), chacune planifiée avec son historique
    /// ou sa charge équivalente. La séance n'est pas changée : `apply(.replaceExercise(…))` fait le remplacement.
    public func replacementOptions(for exerciseID: UUID, reason: ReplacementReason) async throws -> [ReplacementOption] {
        try await queue.run {
            guard let session = try await self.loadSession() else { throw ActiveSessionError.noSession }
            guard let exercise = session.exercises.first(where: { $0.id == exerciseID }) else { return [] }
            let directory = try await self.directory()
            let profile = try await self.profiles.load()
            let inSession = Set(session.exercises.map(\.exercise))
            var options: [ReplacementOption] = []
            for info in ReplacementPlanner.alternatives(for: exercise.exercise, directory: directory, profile: profile,
                                                        excluding: inSession) {
                if let replacement = try await self.plannedReplacement(
                    of: exercise, with: info.reference, reason: reason, session: session, directory: directory, profile: profile) {
                    options.append(ReplacementOption(info: info, exercise: replacement))
                }
            }
            return options
        }
    }

    /// Le remplaçant de `exerciseID` par un exercice choisi dans la bibliothèque, ou `nil` s'il ne reste rien à remplacer.
    public func replacement(for exerciseID: UUID, with reference: ExerciseReference,
                            reason: ReplacementReason) async throws -> LiveExercise? {
        try await queue.run {
            guard let session = try await self.loadSession() else { throw ActiveSessionError.noSession }
            guard let exercise = session.exercises.first(where: { $0.id == exerciseID }) else { return nil }
            return try await self.plannedReplacement(of: exercise, with: reference, reason: reason, session: session,
                                                     directory: try await self.directory(),
                                                     profile: try await self.profiles.load())
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func plannedReplacement(of exercise: LiveExercise, with reference: ExerciseReference, reason: ReplacementReason,
                                    session: LiveSession, directory: ExerciseDirectory,
                                    profile: UserProfile?) async throws -> LiveExercise? {
        ReplacementPlanner.replacement(of: exercise, with: reference, reason: reason, directory: directory,
                                       history: try await workouts.lastSets(for: reference,
                                                                            startedBefore: session.proposalHistoryLimit),
                                       settings: try await settings.settings(for: reference), profile: profile,
                                       policy: session.policy, loadFactor: session.addedLoadFactor)
    }
}
