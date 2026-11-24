import Foundation
import Observation
import PhotosFeature
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
    /// La même série dite en mots : « 70 kilos, 5 répétitions », « assistance de 15 kilos, 8 répétitions », « 45 secondes ».
    public var spokenText: String

    public init(id: UUID, text: String, spokenText: String? = nil, type: SetType, rpe: Double?, isRecord: Bool) {
        self.id = id
        self.text = text
        self.spokenText = spokenText ?? text
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

/// Le détail d'une séance passée (spec M4 §12), avec « Enregistrer comme routine », la suppression et la correction (spec M6 §8).
@MainActor
@Observable
public final class SessionDetailModel {
    public private(set) var session: WorkoutSession?
    public private(set) var blocks: [SessionExerciseBlock] = []
    public private(set) var muscleLevels: [MuscleMapRegion: Int] = [:]
    /// Ce que VoiceOver lit pour la carte musculaire : « Muscles travaillés par la séance. Pectoraux, intensité forte. … ».
    public private(set) var musclesSpokenText = ""
    /// Vrai une fois la séance lue, qu'elle ait été trouvée ou non.
    public private(set) var hasLoaded = false
    public private(set) var isMissing = false
    public private(set) var errorMessage: String?
    /// La section Photos ; `nil` sans service des photos, ou pour une séance qui n'en accepte pas (Apple Santé). Créée une fois la
    /// séance lue, et gardée : relire la séance (après une correction) ne vide pas la section.
    public private(set) var photos: SessionPhotosModel?

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
            photos = makePhotos(for: session)
            blocks = session.map(makeBlocks(of:)) ?? []
            muscleLevels = session.map { MuscleIntensity.levels(weights: muscleWeights(of: $0)) } ?? [:]
            musclesSpokenText = session.map { Self.musclesSpokenText(weights: muscleWeights(of: $0)) } ?? ""
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette séance.", bundle: .module)
        }
    }

    /// « Muscles travaillés par la séance. Pectoraux, intensité forte. Triceps, intensité moyenne. »
    static func musclesSpokenText(weights: [Muscle: Double]) -> String {
        let summary = MuscleMapSummary.text(levels: MuscleIntensity.byMuscle(weights: weights))
        return String(localized: "Muscles travaillés par la séance. \(summary)", bundle: .module)
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

    /// La correction à ouvrir, depuis la séance telle qu'enregistrée.
    public func correction() -> SessionCorrection? {
        session.map(SessionCorrection.init(session:))
    }

    /// Les exercices de la séance et leurs séries corrigeables, dans l'ordre, pour la feuille de correction.
    public var correctableBlocks: [(name: String, setIDs: [UUID])] {
        blocks.compactMap { block in
            let ids = block.sets.filter { $0.type != .warmup }.map(\.id)
            return ids.isEmpty ? nil : (block.name, ids)
        }
    }

    /// Enregistre la séance corrigée, relue à l'instant, puis recalcule les records et relit le détail (spec M6 §8).
    public func save(_ correction: SessionCorrection) async throws {
        guard let fresh = try await environment.workouts.session(id: sessionID) else { throw SessionDetailError.missing }
        let corrected = correction.applied(to: fresh, loadKind: directory.loadKind(of:), now: environment.now())
        guard corrected != fresh else { return }
        try await environment.workouts.save(corrected)
        _ = try await environment.records.recomputeAll()
        await load()
    }

    /// Supprime la séance puis recalcule les records, qu'elle a pu établir, et supprime son entraînement Apple Santé
    /// (spec M4 §19.5).
    public func delete() async throws {
        let deleted = try await environment.workouts.session(id: sessionID)
        try await environment.workouts.delete(id: sessionID)
        if let deleted { await environment.activeSession.health?.removeWorkout(of: deleted) }
        _ = try await environment.records.recomputeAll()
        session = nil
        isMissing = true
        blocks = []
        muscleLevels = [:]
        musclesSpokenText = ""
        photos = nil
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
        summary(spoken: false)
    }

    /// « 1 heure 5 minutes, 12 séries, 4 250 kilos, 2 records » : `summaryText` dit en mots.
    public var summarySpokenText: String {
        summary(spoken: true)
    }

    /// Ce que VoiceOver lit en tête du détail : la date, les marques « importée de Hevy » et « abandonnée », puis le résumé dit.
    public var headerSpokenText: String {
        guard let session else { return "" }
        var parts = [dateText]
        if session.source == .hevy { parts.append(String(localized: "importée de Hevy", bundle: .module)) }
        if session.status == .abandoned { parts.append(String(localized: "abandonnée", bundle: .module)) }
        parts.append(summarySpokenText)
        return parts.joined(separator: ", ")
    }

    private func summary(spoken: Bool) -> String {
        guard let session else { return "" }
        let working = session.sets.filter { $0.setType != .warmup }
        var parts: [String] = []
        if let minutes = HistoryModel.durationMinutes(of: session), minutes > 0 {
            parts.append(spoken ? PulseSpoken.duration(seconds: minutes * 60) : PulseFormat.duration(minutes: minutes))
        }
        parts.append(TrainText.sets(working.count))
        let tonnage = SessionTonnage.kilograms(of: session.sets, loadKind: directory.loadKind(of:))
        if tonnage > 0 { parts.append(spoken ? TrainText.tonnage(tonnage) : HistoryRow.tonnage(tonnage)) }
        let records = working.filter(\.isPersonalRecord).count
        if records > 0 { parts.append(TrainText.records(records)) }
        return parts.joined(separator: spoken ? ", " : " · ")
    }

    // MARK: - Partage

    /// La carte de partage de la séance : pour la musculation, durée, tonnage, séries et records avec la carte musculaire ; pour
    /// une course ou une sortie, distance, durée et allure. `nil` tant que la séance n'est pas lue.
    public var shareContent: ShareCardContent? {
        guard let session else { return nil }
        let day = environment.text(of: session.startedAt) { $0.weekday(.wide).day().month(.wide) }
        if session.kind != .strength {
            return Self.enduranceShareContent(of: session, day: day)
        }
        let working = session.sets.filter { $0.setType != .warmup }
        var metrics: [ShareCardMetric] = []
        if let minutes = HistoryModel.durationMinutes(of: session), minutes > 0 {
            let text = PulseFormat.duration(minutes: minutes)
            metrics.append(ShareCardMetric(value: text, label: String(localized: "Durée", bundle: .module), caption: text))
        }
        let tonnage = SessionTonnage.kilograms(of: session.sets, loadKind: directory.loadKind(of:))
        if tonnage > 0 {
            metrics.append(ShareCardMetric(value: PulseFormat.grouped(tonnage, maxFractionDigits: 0),
                                           label: String(localized: "kg soulevés", bundle: .module), caption: HistoryRow.tonnage(tonnage)))
        }
        metrics.append(ShareCardMetric(value: "\(working.count)", label: String(localized: "Séries", bundle: .module),
                                       caption: TrainText.sets(working.count)))
        let records = working.filter(\.isPersonalRecord).count
        if records > 0 {
            metrics.append(ShareCardMetric(value: "\(records)", label: String(localized: "Records", bundle: .module),
                                           caption: TrainText.records(records)))
        }
        let highlights = blocks.compactMap { block in
            block.sets.first(where: \.isRecord).map { "\(block.name) : \($0.text)" }
        }
        return ShareCardContent(
            eyebrow: String(localized: "Séance", bundle: .module),
            title: session.title.isEmpty ? String(localized: "Séance", bundle: .module) : session.title,
            subtitle: day, metrics: metrics, highlights: highlights, visual: muscleLevels.isEmpty ? .none : .muscles(muscleLevels))
    }

    /// Une course ou une sortie vélo : la distance, la durée et l'allure (au km pour la course, en km/h pour le vélo).
    static func enduranceShareContent(of session: WorkoutSession, day: String) -> ShareCardContent {
        var metrics: [ShareCardMetric] = []
        let distance = session.distanceMeters.flatMap { $0 > 0 ? $0 : nil }
        if let distance {
            let text = String(localized: "\(PulseFormat.decimal(distance / 1_000, maxFractionDigits: 2)) km", bundle: .module)
            metrics.append(ShareCardMetric(value: text, label: String(localized: "Distance", bundle: .module), caption: text))
        }
        let minutes = HistoryModel.durationMinutes(of: session) ?? 0
        if minutes > 0 {
            let text = PulseFormat.duration(minutes: minutes)
            metrics.append(ShareCardMetric(value: text, label: String(localized: "Durée", bundle: .module), caption: text))
        }
        if let distance, distance >= 100, minutes > 0, let speed = speedText(of: session, meters: distance, minutes: minutes) {
            metrics.append(ShareCardMetric(value: speed, label: String(localized: "Allure", bundle: .module), caption: speed))
        }
        if let bpm = session.averageHeartRate {
            let text = PulseFormat.integer(bpm, unit: "bpm")
            metrics.append(ShareCardMetric(value: text, label: String(localized: "FC moyenne", bundle: .module), caption: text))
        }
        let isRide = session.kind == .ride
        let kind = isRide ? String(localized: "Vélo", bundle: .module) : String(localized: "Course", bundle: .module)
        return ShareCardContent(eyebrow: kind, title: session.title.isEmpty ? kind : session.title, subtitle: day, metrics: metrics)
    }

    /// « 5'29"/km » pour une course, « 24,5 km/h » pour une sortie vélo.
    nonisolated static func speedText(of session: WorkoutSession, meters: Double, minutes: Int) -> String? {
        let kilometres = meters / 1_000
        if session.kind == .ride {
            let speed = kilometres / (Double(minutes) / 60)
            return String(localized: "\(PulseFormat.decimal(speed, maxFractionDigits: 1)) km/h", bundle: .module)
        }
        let secondsPerKm = Int((Double(minutes * 60) / kilometres).rounded())
        guard secondsPerKm > 0 else { return nil }
        let rest = secondsPerKm % 60
        return "\(secondsPerKm / 60)'\(rest < 10 ? "0" : "")\(rest)\"/km"
    }

    // MARK: - Interne

    /// Le modèle de la section Photos de `session`, gardé s'il existe déjà ; `nil` sans service ou pour une séance qui n'accepte
    /// pas de photos.
    private func makePhotos(for session: WorkoutSession?) -> SessionPhotosModel? {
        guard let session, SessionPhotoRules.acceptsPhotos(session), let service = environment.sessionPhotos else { return nil }
        return photos ?? SessionPhotosModel(service: service, sessionID: session.id, calendar: environment.calendar)
    }

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
        SessionSetLine(id: set.id, text: Self.text(of: set),
                       spokenText: TrainText.spokenSet(of: set, loadKind: directory.loadKind(of: set.exercise)), type: set.setType,
                       rpe: set.rpe, isRecord: set.isPersonalRecord)
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
