import Foundation
import Observation
import PulseDesignSystem
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// Ce qui empêche d'enregistrer une séance comme routine.
public enum SessionDetailError: Error, Equatable, Sendable {
    /// La séance est introuvable.
    case missing
    /// La séance n'a aucune série hors échauffement : il n'y a rien à reprendre.
    case nothingToSave
}

/// Une série du détail d'une séance.
public struct SessionSetLine: Identifiable, Equatable, Sendable {
    public var id: UUID
    /// « 70 × 5 », « 8 » sans charge, « 45 s » pour une série tenue.
    public var text: String
    public var type: SetType
    public var rpe: Double?
    public var isRecord: Bool

    public init(id: UUID, text: String, type: SetType, rpe: Double?, isRecord: Bool) {
        self.id = id
        self.text = text
        self.type = type
        self.rpe = rpe
        self.isRecord = isRecord
    }
}

/// Un exercice de la séance : sa note et ses séries, dans l'ordre.
public struct SessionExerciseBlock: Identifiable, Equatable, Sendable {
    public var exercise: ExerciseReference
    public var name: String
    public var note: String?
    public var sets: [SessionSetLine]

    public init(exercise: ExerciseReference, name: String, note: String?, sets: [SessionSetLine]) {
        self.exercise = exercise
        self.name = name
        self.note = note
        self.sets = sets
    }

    public var id: ExerciseReference { exercise }
}

/// Le détail, en lecture seule, d'une séance passée (spec M4 §12), avec « Enregistrer comme routine » et la suppression.
@MainActor
@Observable
public final class SessionDetailModel {
    public private(set) var session: WorkoutSession?
    public private(set) var blocks: [SessionExerciseBlock] = []
    public private(set) var muscleLevels: [MuscleMapRegion: Int] = [:]
    /// Vrai une fois la séance lue, qu'elle ait été trouvée ou non.
    public private(set) var hasLoaded = false
    public private(set) var isMissing = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let environment: TrainEnvironment
    @ObservationIgnored private let sessionID: UUID
    @ObservationIgnored private var directory: ExerciseDirectory

    public init(environment: TrainEnvironment, sessionID: UUID) {
        self.environment = environment
        self.sessionID = sessionID
        directory = ExerciseDirectory(library: environment.library, userExercises: [])
    }

    /// Relit la séance et les exercices de l'utilisateur. Si la lecture échoue, l'écran affiche une erreur.
    public func load() async {
        do {
            let userExercises = try await environment.userExercises.all(includeArchived: true)
            directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
            session = try await environment.workouts.session(id: sessionID)
            isMissing = session == nil
            blocks = session.map(makeBlocks(of:)) ?? []
            muscleLevels = session.map { MuscleIntensity.levels(weights: muscleWeights(of: $0)) } ?? [:]
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette séance.", bundle: .module)
        }
    }

    /// Vrai si la séance a au moins une série hors échauffement.
    public var canSaveAsRoutine: Bool {
        session?.sets.contains { $0.setType != .warmup } ?? false
    }

    /// Ajoute la séance, reprise comme routine, au programme actif ; sans programme actif, dans un nouveau programme « Mon
    /// programme » qui le devient. Rend le programme et la routine, que l'éditeur ouvre ensuite.
    public func saveAsRoutine() async throws -> (programID: UUID, dayID: UUID) {
        guard let session else { throw SessionDetailError.missing }
        guard canSaveAsRoutine else { throw SessionDetailError.nothingToSave }
        guard var profile = try await environment.profiles.load() else { throw ProgramEditorError.noProfile }
        let now = environment.now()
        let existing = try await activeProgram(of: profile)
        let base = existing ?? ProgramEditor.emptyProgram(name: ProgramEditorModel.defaultProgramName, now: now)
        let routine = RoutineFromSession.day(from: session, directory: directory, order: base.days.count)
        let (program, dayID) = ProgramEditor.addDay(named: routineName(of: session), exercises: routine.exercises, to: base, now: now)
        try await environment.programs.save(program)
        if profile.activeProgramID != program.id {
            profile.activeProgramID = program.id
            profile.updatedAt = now
            try await environment.profiles.save(profile)
        }
        return (program.id, dayID)
    }

    /// Supprime la séance puis recalcule les records, qu'elle a pu établir.
    public func delete() async throws {
        try await environment.workouts.delete(id: sessionID)
        _ = try await environment.records.recomputeAll()
        session = nil
        isMissing = true
        blocks = []
        muscleLevels = [:]
    }

    /// « lundi 12 octobre 2026 à 18:00 », dans le calendrier de l'environnement.
    public var dateText: String {
        guard let date = session?.startedAt else { return "" }
        let day = environment.text(of: date) { $0.weekday(.wide).day().month(.wide).year() }
        let time = environment.text(of: date) { $0.hour().minute() }
        return String(localized: "\(day) à \(time)", bundle: .module)
    }

    /// « 1 h 05 · 12 séries · 4 250 kg · 2 records » (les éléments inconnus ou nuls sont omis).
    public var summaryText: String {
        guard let session else { return "" }
        let working = session.sets.filter { $0.setType != .warmup }
        var parts: [String] = []
        if let minutes = HistoryModel.durationMinutes(of: session), minutes > 0 { parts.append(PulseFormat.duration(minutes: minutes)) }
        parts.append(String(localized: "\(working.count) séries", bundle: .module))
        let tonnage = SessionTonnage.kilograms(of: session.sets, loadKind: directory.loadKind(of:))
        if tonnage > 0 { parts.append(HistoryRow.tonnage(tonnage)) }
        let records = working.filter(\.isPersonalRecord).count
        if records > 0 { parts.append(String(localized: "\(records) records", bundle: .module)) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Interne

    private func activeProgram(of profile: UserProfile) async throws -> Program? {
        guard let id = profile.activeProgramID, let program = try await environment.programs.program(id: id) else { return nil }
        return program.isArchived ? nil : program
    }

    private func routineName(of session: WorkoutSession) -> String {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? String(localized: "Nouvelle routine", bundle: .module) : title
    }

    /// Les exercices dans l'ordre de leur première série, chacun avec toutes ses séries, échauffement compris.
    private func makeBlocks(of session: WorkoutSession) -> [SessionExerciseBlock] {
        var order: [ExerciseReference] = []
        var setsByExercise: [ExerciseReference: [WorkoutSet]] = [:]
        for set in session.sets.sorted(by: { $0.order < $1.order }) {
            if setsByExercise[set.exercise] == nil { order.append(set.exercise) }
            setsByExercise[set.exercise, default: []].append(set)
        }
        return order.map { reference in
            let sets = setsByExercise[reference] ?? []
            let note = session.exerciseNotes.first { $0.exercise == reference }?.text
            return SessionExerciseBlock(
                exercise: reference, name: directory.name(of: reference, fallback: sets.first?.exerciseName ?? ""),
                note: note?.isEmpty == false ? note : nil, sets: sets.map(line(for:)))
        }
    }

    private func line(for set: WorkoutSet) -> SessionSetLine {
        SessionSetLine(id: set.id, text: Self.text(of: set), type: set.setType, rpe: set.rpe, isRecord: set.isPersonalRecord)
    }

    /// « 70 × 5 » ; sans charge « 8 » ; une série tenue « 45 s » ; « — » sans rien de saisi.
    static func text(of set: WorkoutSet) -> String {
        let weight = set.actualWeightKg ?? 0
        if let reps = set.actualReps, reps > 0 {
            return weight > 0 ? "\(PulseFormat.decimal(weight, maxFractionDigits: 2)) × \(reps)" : "\(reps)"
        }
        if let seconds = set.durationSeconds, seconds > 0 {
            return weight > 0
                ? "\(PulseFormat.decimal(weight, maxFractionDigits: 2)) × \(PulseFormat.restDuration(seconds: seconds))"
                : PulseFormat.restDuration(seconds: seconds)
        }
        return "—"
    }

    /// 1 par série de travail pour un muscle principal, 0,5 pour un secondaire (spec M3 §6.3) ; une référence inconnue est ignorée.
    private func muscleWeights(of session: WorkoutSession) -> [Muscle: Double] {
        var weights: [Muscle: Double] = [:]
        for set in session.sets where set.setType != .warmup {
            guard let info = directory.info(set.exercise) else { continue }
            for muscle in info.primaryMuscles { weights[muscle, default: 0] += 1 }
            for muscle in info.secondaryMuscles where !info.primaryMuscles.contains(muscle) { weights[muscle, default: 0] += 0.5 }
        }
        return weights
    }
}
