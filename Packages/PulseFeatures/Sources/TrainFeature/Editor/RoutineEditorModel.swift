import Foundation
import Observation
import PulseDomain
import PulseServices

/// Ce qui empêche d'enregistrer une routine.
public enum RoutineEditorError: Error, Equatable, Sendable {
    /// Un exercice sort des limites, ou la routine n'a pas de nom.
    case invalid
    /// Le programme ou la routine n'existe plus.
    case missing
}

/// L'éditeur d'une routine de musculation (spec M4 §11.2). Les modifications se font sur un brouillon : rien n'est enregistré
/// avant `save()`, qui refuse tant qu'un exercice sort de ses limites. L'incrément, lui, est un réglage de l'exercice : il est
/// écrit tout de suite dans `ExerciseSettings`.
@MainActor
@Observable
public final class RoutineEditorModel {
    private static let fallbackIncrementKg = 2.5

    public private(set) var day: RoutineDay
    public private(set) var directory: ExerciseDirectory
    /// Vrai une fois la routine lue, qu'elle ait été trouvée ou non.
    public private(set) var hasLoaded = false
    /// Vrai si le programme ou la routine est introuvable, ou si la routine n'est pas de musculation (modifiable en M6).
    public private(set) var isMissing = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let environment: TrainEnvironment
    @ObservationIgnored private let programID: UUID
    private var saved: RoutineDay
    private var profile: UserProfile?
    private var settings: [ExerciseReference: ExerciseSettings] = [:]

    public init(environment: TrainEnvironment, programID: UUID, dayID: UUID) {
        self.environment = environment
        self.programID = programID
        let placeholder = RoutineDay(id: dayID, order: 0, name: "", kind: .strength)
        day = placeholder
        saved = placeholder
        directory = ExerciseDirectory(library: environment.library, userExercises: [])
    }

    /// Lit la routine, les exercices de l'utilisateur, le profil et les réglages. Sans effet une fois la routine lue : revenir de
    /// la bibliothèque ne doit pas défaire le brouillon. Si une lecture échoue, l'écran affiche une erreur.
    public func load() async {
        guard !hasLoaded else { return }
        do {
            let program = try await environment.programs.program(id: programID)
            try await refreshReferences()
            if var found = program?.days.first(where: { $0.id == day.id }), found.kind == .strength {
                found.exercises.sort { $0.order < $1.order }
                day = found
                saved = found
            } else {
                isMissing = true
            }
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette routine.", bundle: .module)
        }
    }

    /// Relit les exercices de l'utilisateur (archivés compris), le profil et les réglages : un exercice perso créé depuis la
    /// bibliothèque est alors connu avant d'être ajouté.
    public func refreshReferences() async throws {
        let userExercises = try await environment.userExercises.all(includeArchived: true)
        directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
        profile = try await environment.profiles.load()
        // Deux réglages du même exercice (restauration iCloud) : le plus récent, comme `settings(for:)`.
        settings = Dictionary(try await environment.exerciseSettings.all().map { ($0.exercise, $0) },
                              uniquingKeysWith: { lhs, rhs in rhs.updatedAt > lhs.updatedAt ? rhs : lhs })
    }

    /// La bibliothèque en choix multiple, sur le même environnement que l'éditeur.
    public func libraryModel() -> LibraryModel {
        LibraryModel(environment: environment, mode: .pick(multiple: true))
    }

    // MARK: - Lecture

    public var estimatedMinutes: Int {
        SessionSummary.make(day: day, directory: directory).estimatedMinutes
    }

    /// Les problèmes de chaque exercice qui en a, par position dans la routine.
    public var issues: [Int: [RoutineIssue]] {
        var result: [Int: [RoutineIssue]] = [:]
        for (index, exercise) in day.exercises.enumerated() {
            let found = RoutineRules.issues(in: exercise, tracksDuration: tracksDuration(exercise.exercise))
            if !found.isEmpty { result[index] = found }
        }
        return result
    }

    /// Vrai si le brouillon diffère de ce qui est enregistré.
    public var hasChanges: Bool {
        day != saved
    }

    public var canSave: Bool {
        hasChanges && issues.isEmpty && !trimmedName.isEmpty
    }

    /// Le nom de l'exercice, ou « Exercice inconnu » si l'annuaire ne le connaît plus.
    public func name(of reference: ExerciseReference) -> String {
        directory.info(reference)?.name ?? String(localized: "Exercice inconnu", bundle: .module)
    }

    /// Un exercice tenu se compte en secondes plutôt qu'en répétitions.
    public func tracksDuration(_ reference: ExerciseReference) -> Bool {
        directory.info(reference)?.tracksDuration ?? false
    }

    /// Vrai si l'exercice `index` est en super set avec le suivant.
    public func isSuperset(at index: Int) -> Bool {
        guard day.exercises.indices.contains(index), day.exercises.indices.contains(index + 1),
              let group = day.exercises[index].supersetGroup else { return false }
        return day.exercises[index + 1].supersetGroup == group
    }

    /// Un super set relie deux exercices consécutifs libres : il y a un suivant, et l'un des deux n'est pas déjà dans une autre paire.
    public func canToggleSuperset(at index: Int) -> Bool {
        guard day.exercises.indices.contains(index), day.exercises.indices.contains(index + 1) else { return false }
        if isSuperset(at: index) { return true }
        return day.exercises[index].supersetGroup == nil && day.exercises[index + 1].supersetGroup == nil
    }

    /// L'incrément de l'exercice : son réglage, sinon le défaut de l'exercice borné par celui du profil.
    public func increment(for reference: ExerciseReference) -> Double {
        let chosen = settings[reference]
        guard let info = directory.info(reference) else { return chosen?.incrementKg ?? Self.fallbackIncrementKg }
        return IncrementResolver.increment(for: info, settings: chosen, profile: profile)
    }

    // MARK: - Brouillon

    public func rename(_ name: String) {
        day.name = name
    }

    public func add(_ references: [ExerciseReference]) {
        day = RoutineEditor.add(references, to: day, directory: directory)
    }

    public func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        day = RoutineEditor.move(fromOffsets: offsets, toOffset: destination, in: day)
    }

    public func remove(at index: Int) {
        day = RoutineEditor.remove(at: index, from: day)
    }

    public func toggleSuperset(at index: Int) {
        day = RoutineEditor.toggleSuperset(at: index, in: day)
    }

    public func setSets(_ count: Int, at index: Int) {
        day = RoutineEditor.setSets(count, at: index, in: day)
    }

    /// Fixe la fourchette de l'exercice. Sans effet avec une fourchette par série : celle de l'exercice en découle alors.
    public func setRange(_ range: SetTarget, at index: Int) {
        guard day.exercises.indices.contains(index), day.exercises[index].setTargets == nil else { return }
        day.exercises[index].repsMin = range.repsMin
        day.exercises[index].repsMax = range.repsMax
    }

    public func setPerSetTargets(_ enabled: Bool, at index: Int) {
        day = RoutineEditor.setPerSetTargets(enabled, at: index, in: day)
    }

    public func updateSetTarget(_ target: SetTarget, set: Int, at index: Int) {
        day = RoutineEditor.updateSetTarget(target, set: set, at: index, in: day)
    }

    public func setRPE(_ rpe: Double, at index: Int) {
        guard day.exercises.indices.contains(index) else { return }
        day.exercises[index].targetRPE = rpe
    }

    public func setRest(_ seconds: Int, at index: Int) {
        guard day.exercises.indices.contains(index) else { return }
        day.exercises[index].restSeconds = seconds
    }

    // MARK: - Enregistrement

    /// Enregistre la routine dans son programme. Refusé (`invalid`) tant qu'un exercice sort de ses limites ou que le nom est vide.
    public func save() async throws {
        guard !isMissing else { throw RoutineEditorError.missing }
        let name = trimmedName
        guard issues.isEmpty, !name.isEmpty else { throw RoutineEditorError.invalid }
        guard let program = try await environment.programs.program(id: programID),
              program.days.contains(where: { $0.id == day.id }) else { throw RoutineEditorError.missing }
        var draft = day
        draft.name = name
        let updated = ProgramEditor.replaceDay(draft, in: program, now: environment.now())
        try await environment.programs.save(updated)
        if let stored = updated.days.first(where: { $0.id == draft.id }) {
            day = stored
            saved = stored
        }
    }

    /// Écrit l'incrément de l'exercice, arrondi au quart de kilo entre 0,25 et 20 kg. Les autres réglages sont gardés.
    public func setIncrement(_ kg: Double, for reference: ExerciseReference) async {
        do {
            let written = try await IncrementStore(settings: environment.exerciseSettings)
                .save(kg, for: reference, now: environment.now())
            settings[reference] = written
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer l'incrément.", bundle: .module)
        }
    }

    private var trimmedName: String {
        day.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
