import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine

public enum ActiveSessionError: Error, Equatable {
    /// Une séance est déjà enregistrée, lisible ou non : la reprendre ou l'abandonner d'abord.
    case alreadyInProgress
    /// Aucune séance lisible en cours.
    case noSession
    /// Le changement n'a pas pu être enregistré : la séance enregistrée reste celle d'avant, sans notification ni Live Activity.
    case notStored
}

/// Le seul chemin vers la séance en cours (spec M4 §14 à §16) : l'écran de séance, les boutons de la Live Activity et la reprise
/// après une relance passent par lui. Tous ses appels passent l'un après l'autre par une même file ; chaque changement est
/// enregistré dans le snapshot avant de rendre la main, puis le repos, sa notification et la Live Activity suivent.
public final class ActiveSessionService: Sendable {
    let store: any ActiveSessionStore
    let workouts: any WorkoutRepository
    let profiles: any ProfileRepository
    let settings: any ExerciseSettingsRepository
    let userExercises: any UserExerciseRepository
    let records: RecordsService
    let library: ContentLibrary
    let restNotifier: any RestTimerNotifying
    let activity: any SessionActivityControlling
    let calendar: Calendar
    let now: @Sendable () -> Date
    /// L'écriture des séances terminées dans Apple Santé (spec M4 §19.5) ; `nil` sans Apple Santé. L'historique s'en sert
    /// aussi pour supprimer l'entraînement d'une séance supprimée.
    public let health: HealthWorkoutExporter?
    /// Les photos des séances ; `nil` sans photos. Seul l'abandon d'une séance non enregistrée s'en sert, pour effacer les
    /// photos prises pendant la séance.
    let sessionPhotos: (any SessionPhotoRepository)?
    let queue = SerialTaskQueue()

    public init(store: any ActiveSessionStore, workouts: any WorkoutRepository, profiles: any ProfileRepository,
                settings: any ExerciseSettingsRepository, userExercises: any UserExerciseRepository, records: RecordsService,
                library: ContentLibrary, restNotifier: any RestTimerNotifying, activity: any SessionActivityControlling,
                calendar: Calendar, now: @escaping @Sendable () -> Date, health: HealthWorkoutExporter? = nil,
                sessionPhotos: (any SessionPhotoRepository)? = nil) {
        self.store = store
        self.workouts = workouts
        self.profiles = profiles
        self.settings = settings
        self.userExercises = userExercises
        self.records = records
        self.library = library
        self.restNotifier = restNotifier
        self.activity = activity
        self.calendar = calendar
        self.now = now
        self.health = health
        self.sessionPhotos = sessionPhotos
    }

    /// La séance en cours, ou `nil` sans snapshot lisible. Un repos fini est effacé, enregistré, et sa notification annulée ;
    /// `lastActionAt` ne bouge pas, une reprise n'étant pas une action.
    public func current() async -> LiveSession? {
        let resumed = try? await queue.run { () async throws -> LiveSession? in
            guard let loaded = try await self.loadSession() else { return nil }
            let now = self.now()
            var session = loaded
            session.clearRest(endedBy: now)
            guard session != loaded else { return loaded }
            // Un échec d'écriture n'empêche pas la reprise : le prochain changement réécrira la séance.
            try? await self.save(session, at: now)
            await self.publish(from: loaded, to: session)
            return session
        }
        return resumed ?? nil
    }

    /// Termine les Live Activities de séance qui ne correspondent plus à la séance en cours (spec M4 §15.3). Le snapshot est lu
    /// dans la même opération de la file : un démarrage qui passe juste avant garde son activité.
    public func closeStaleActivities() async {
        _ = try? await queue.run {
            await self.activity.endAll(except: try? await self.loadSession()?.id)
        }
    }

    /// Planifie la séance, l'enregistre, puis démarre la Live Activity, sauf pour une séance passée. Une séance lisible déjà
    /// en cours bloque le départ ; un snapshot illisible, qui ne pourra jamais être repris, est effacé avec sa Live Activity
    /// et sa notification.
    public func start(_ launch: SessionLaunch) async throws -> LiveSession {
        try await queue.run {
            try await self.discardUnreadableSnapshot()
            let directory = try await self.directory()
            let profile = try await self.profiles.load()
            var history: [ExerciseReference: [WorkoutSet]] = [:]
            var settingsByExercise: [ExerciseReference: ExerciseSettings] = [:]
            let historyLimit = min(launch.past?.start ?? .distantFuture, launch.historyLimit ?? .distantFuture)
            for reference in launch.day?.exercises.map(\.exercise) ?? [] where history[reference] == nil {
                history[reference] = try await self.workouts.lastSets(for: reference, startedBefore: historyLimit)
                settingsByExercise[reference] = try await self.settings.settings(for: reference)
            }
            let session = LiveSessionPlanner.session(for: launch, directory: directory, history: history,
                                                     settings: settingsByExercise, profile: profile, now: self.now())
            try await self.save(session, at: session.lastActionAt)
            if !session.isPastEntry { await self.activity.start(Self.activityState(for: session)) }
            return session
        }
    }

    /// Les exercices à ajouter en séance, planifiés avec leur historique, la règle de hausse du jour et, en décharge, la baisse
    /// de charge du lancement. La séance n'est pas changée : `apply(.addExercises(_:))` les ajoute.
    public func newExercises(_ references: [ExerciseReference]) async throws -> [LiveExercise] {
        try await queue.run {
            guard let session = try await self.loadSession() else { throw ActiveSessionError.noSession }
            let directory = try await self.directory()
            let profile = try await self.profiles.load()
            var added: [LiveExercise] = []
            // Un muscle déjà travaillé dans la séance n'est pas échauffé une seconde fois (spec M4 §8.3).
            var worked = Set(session.exercises.flatMap { directory.info($0.exercise)?.primaryMuscles ?? [] })
            for reference in references {
                added.append(LiveSessionPlanner.exercise(
                    reference, directory: directory,
                    history: try await self.workouts.lastSets(for: reference, startedBefore: session.proposalHistoryLimit),
                    settings: try await self.settings.settings(for: reference), profile: profile, policy: session.policy,
                    workedMuscles: worked, loadFactor: session.addedLoadFactor))
                worked.formUnion(directory.info(reference)?.primaryMuscles ?? [])
            }
            return added
        }
    }

    /// Enregistre le nombre de séries d'échauffement de l'exercice dans ses réglages, pour toutes les routines ; `nil` revient
    /// à l'automatique. La séance en cours change par `apply(.setWarmupCount(…))`.
    public func saveWarmupCount(_ count: Int?, for reference: ExerciseReference) async throws {
        try await queue.run {
            let now = self.now()
            var settings = try await self.settings.settings(for: reference)
                ?? ExerciseSettings(exercise: reference, createdAt: now, updatedAt: now)
            settings.warmupSetCount = count
            settings.updatedAt = now
            try await self.settings.save(settings)
        }
    }

    /// Enregistre l'incrément de charge de l'exercice dans ses réglages, pour toutes les routines et les prochaines séances, comme
    /// la fiche exercice. La séance en cours change par `apply(.setIncrement(…))`. Un incrément nul ou négatif n'est pas enregistré.
    public func saveIncrement(_ incrementKg: Double, for reference: ExerciseReference) async throws {
        guard incrementKg > 0 else { return }
        try await queue.run {
            let now = self.now()
            var settings = try await self.settings.settings(for: reference)
                ?? ExerciseSettings(exercise: reference, createdAt: now, updatedAt: now)
            settings.incrementKg = incrementKg
            settings.updatedAt = now
            try await self.settings.save(settings)
        }
    }

    /// La barre et les disques du profil, ou ceux d'une salle courante sans profil (barre de 20 kg, disques de 25 à 1,25 kg).
    public func barAndPlates() async throws -> (barKg: Double, platesKg: [Double]) {
        let profile = try await profiles.load() ?? UserProfile(createdAt: now(), updatedAt: now())
        return (profile.barWeightKg, profile.availablePlatesKg)
    }

    /// Enregistre la barre et les disques disponibles dans le profil (spec M4 §8.3 : le calculateur les règle, l'écran
    /// Paramètres arrive en M7). Sans profil, rien n'est enregistré.
    public func saveBarAndPlates(barKg: Double, platesKg: [Double]) async throws {
        try await queue.run {
            let now = self.now()
            let plates = platesKg.filter { $0 > 0 }.sorted(by: >)
            try await self.profiles.update { profile in
                profile.barWeightKg = barKg
                profile.availablePlatesKg = plates
                profile.updatedAt = now
            }
        }
    }

    /// Applique le geste, pose `lastActionAt`, enregistre la séance, puis règle la notification et la Live Activity. Une séance
    /// passée n'a pas de repos.
    public func apply(_ change: LiveSessionChange) async throws -> LiveSession {
        try await queue.run {
            guard let loaded = try await self.loadSession() else { throw ActiveSessionError.noSession }
            return try await self.apply(change, to: loaded)
        }
    }

    /// Le corps de `apply(_:)`, sur la séance déjà lue, à appeler depuis une opération de la file.
    func apply(_ change: LiveSessionChange, to loaded: LiveSession) async throws -> LiveSession {
        let now = self.now()
        var session = loaded
        session.clearRest(endedBy: now)
        let before = session
        session.applyStructure(change, now: now)
        session.rest = session.isPastEntry ? nil : Self.rest(after: change, before: before, session: session, now: now)
        session.lastActionAt = now
        try await save(session, at: now)
        await publish(from: loaded, to: session)
        return session
    }

    /// La séance du snapshot, ou `nil` sans snapshot ou s'il est illisible.
    func loadSession() async throws -> LiveSession? {
        guard let snapshot = try await store.load() else { return nil }
        return LiveSession.decode(snapshot.payload)
    }

    /// Lève `alreadyInProgress` si une séance lisible est enregistrée ; efface un snapshot illisible (format inconnu, écriture
    /// corrompue), termine toute Live Activity de séance et annule la notification de repos.
    private func discardUnreadableSnapshot() async throws {
        guard let snapshot = try await store.load() else { return }
        guard LiveSession.decode(snapshot.payload) == nil else { throw ActiveSessionError.alreadyInProgress }
        try await store.clear()
        await activity.endAll(except: nil)
        await restNotifier.cancelRestEnd()
    }

    func save(_ session: LiveSession, at date: Date) async throws {
        do {
            let snapshot = ActiveSessionSnapshot(id: session.id, startedAt: session.startedAt, updatedAt: date,
                                                 payload: try session.encoded())
            try await store.save(snapshot)
        } catch {
            throw ActiveSessionError.notStored
        }
    }

    /// Les exercices archivés restent connus : une routine ou un historique peut encore les nommer.
    func directory() async throws -> ExerciseDirectory {
        ExerciseDirectory(library: library, userExercises: try await userExercises.all(includeArchived: true))
    }
}
