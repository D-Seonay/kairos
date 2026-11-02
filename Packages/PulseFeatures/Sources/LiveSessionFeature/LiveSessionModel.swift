import Foundation
import Observation
import PulseDomain
import PulseServices
import TrainFeature

/// L'état de l'écran de séance : la séance en cours, le champ que le clavier édite, et les gestes qui deviennent des
/// `LiveSessionChange` (spec M4 §14.3 à §14.5, §15.1). Chaque geste passe par `ActiveSessionService.apply` et prend la séance
/// qu'il rend ; une erreur laisse la séance telle qu'elle était et s'affiche dans `errorMessage`.
@MainActor
@Observable
public final class LiveSessionModel {
    public private(set) var session: LiveSession
    /// Le champ édité par le clavier ; `nil` clavier fermé.
    public private(set) var focus: KeypadField?
    public private(set) var keypad = KeypadInput(field: .weight, increment: 2.5)
    public private(set) var errorMessage: String?
    public var isSaving: Bool { pendingChanges > 0 }

    @ObservationIgnored let environment: LiveSessionEnvironment
    @ObservationIgnored private let haptics: LiveSessionHaptics
    @ObservationIgnored private var pendingChanges = 0
    /// Le début du repos dont la fin a déjà fait vibrer : +30 s ne la fait pas vibrer deux fois.
    @ObservationIgnored private var vibratedRestStart: Date?

    init(session: LiveSession, environment: LiveSessionEnvironment, haptics: LiveSessionHaptics = .system) {
        self.session = session
        self.environment = environment
        self.haptics = haptics
    }

    /// L'environnement de l'onglet Séance, pour la bibliothèque en mode choix et la fiche d'un exercice.
    public var train: TrainEnvironment { environment.train }

    /// Reprend une séance relue du service (retour au premier plan, bouton de la Live Activity), sauf pendant un geste.
    func sync(with session: LiveSession) {
        guard pendingChanges == 0, session.id == self.session.id else { return }
        self.session = session
    }

    // MARK: Série

    /// La coche : valide la série, avec une double vibration, ou la dévalide si elle l'est déjà. Sans répétitions (ou secondes)
    /// ni proposition, ou sans charge pour un exercice à charge externe, elle ouvre le clavier sur le champ manquant
    /// **(choix du constructeur)**.
    public func tap(set id: UUID) async {
        guard let exercise = session.exercises.first(where: { $0.sets.contains { $0.id == id } }),
              let set = exercise.sets.first(where: { $0.id == id }) else { return }
        if set.completedAt != nil {
            await perform(.unvalidate(exercise: exercise.id, set: id))
        } else if let missing = Self.missingField(of: set, in: exercise) {
            focus(KeypadField(exercise: exercise.id, set: id, kind: missing))
        } else if await perform(.validate(exercise: exercise.id, set: id)) {
            haptics.validation()
        }
    }

    /// Lie le clavier à ce champ, sur sa valeur actuelle ; `nil` ferme le clavier.
    public func focus(_ field: KeypadField?) {
        focus = field
        guard let field, let exercise = session.exercises.first(where: { $0.id == field.exercise }),
              let set = exercise.sets.first(where: { $0.id == field.set }) else { return }
        keypad = KeypadInput(field: field.kind, increment: exercise.incrementKg)
        keypad.start(with: Self.value(of: field.kind, in: set))
    }

    /// Une touche du clavier. « Suivant » passe de la charge aux répétitions (ou secondes), puis à la série suivante de
    /// l'exercice, puis ferme le clavier ; les autres touches modifient la valeur.
    public func keypadKey(_ key: KeypadInput.Key) async {
        guard let focus else { return }
        if key == .next {
            advance(from: focus)
            return
        }
        let value = keypad.apply(key)
        haptics.light()
        switch focus.kind {
        case .weight:
            await perform(.edit(exercise: focus.exercise, set: focus.set, weightKg: .some(value)))
        case .reps:
            await perform(.edit(exercise: focus.exercise, set: focus.set, reps: .some(value.map { Int($0) })))
        case .duration:
            await perform(.edit(exercise: focus.exercise, set: focus.set, durationSeconds: .some(value.map { Int($0) })))
        }
    }

    /// Le RPE d'une série, de 6 à 10 par pas de 0,5 ; `nil` l'efface. Une autre valeur est ignorée.
    public func setRPE(_ rpe: Double?, set: UUID) async {
        if let rpe, !(6...10).contains(rpe) || (rpe * 2).rounded() != rpe * 2 { return }
        guard let exercise = exerciseID(containing: set) else { return }
        haptics.light()
        await perform(.edit(exercise: exercise, set: set, rpe: .some(rpe)))
    }

    public func setType(_ type: SetType, set: UUID) async {
        guard let exercise = exerciseID(containing: set) else { return }
        await perform(.setType(exercise: exercise, set: set, type))
    }

    public func addSet(exercise: UUID) async {
        await perform(.addSet(exercise: exercise))
    }

    public func deleteSet(_ set: UUID) async {
        guard let exercise = exerciseID(containing: set) else { return }
        if focus?.set == set { focus = nil }
        await perform(.deleteSet(exercise: exercise, set: set))
    }

    // MARK: Exercices

    /// Planifie les exercices (historique et charges proposées) puis les ajoute à la séance.
    public func addExercises(_ references: [ExerciseReference]) async {
        guard !references.isEmpty else { return }
        pendingChanges += 1
        defer { pendingChanges -= 1 }
        do {
            let added = try await environment.service.newExercises(references)
            session = try await environment.service.apply(.addExercises(added))
            errorMessage = nil
        } catch {
            errorMessage = Self.saveFailure
        }
    }

    public func removeExercise(_ exercise: UUID) async {
        if focus?.exercise == exercise { focus = nil }
        await perform(.removeExercise(exercise))
    }

    public func moveExercise(_ exercise: UUID, by offset: Int) async {
        await perform(.moveExercise(exercise, by: offset))
    }

    public func setNote(_ note: String?, exercise: UUID) async {
        await perform(.setNote(exercise: exercise, note))
    }

    public func setIncrement(_ incrementKg: Double, exercise: UUID) async {
        await perform(.setIncrement(exercise: exercise, incrementKg))
        // Le tampon vaut la valeur enregistrée : rouvrir le champ lui donne le nouvel incrément.
        if let focus, focus.exercise == exercise { self.focus(focus) }
    }

    // MARK: Repos

    public func restMinus30() async {
        await perform(.restMinus30)
    }

    public func restPlus30() async {
        await perform(.restPlus30)
    }

    public func skipRest() async {
        await perform(.skipRest)
    }

    /// Le temps de repos restant à `now`, ou `nil` sans repos ou une fois fini.
    public func restRemaining(at now: Date) -> TimeInterval? {
        guard let rest = session.rest, rest.endsAt > now else { return nil }
        return rest.endsAt.timeIntervalSince(now)
    }

    /// L'écran appelle cette méthode quand le repos arrive à sa fin : une vibration longue, une seule fois par repos.
    public func didReachRestEnd() {
        guard let rest = session.rest, vibratedRestStart != rest.startedAt else { return }
        vibratedRestStart = rest.startedAt
        haptics.restEnded()
    }

    // MARK: Interne

    @discardableResult
    private func perform(_ change: LiveSessionChange) async -> Bool {
        pendingChanges += 1
        defer { pendingChanges -= 1 }
        do {
            session = try await environment.service.apply(change)
            errorMessage = nil
            return true
        } catch {
            errorMessage = Self.saveFailure
            return false
        }
    }

    private func exerciseID(containing set: UUID) -> UUID? {
        session.exercises.first { $0.sets.contains { $0.id == set } }?.id
    }

    private func advance(from field: KeypadField) {
        guard let exercise = session.exercises.first(where: { $0.id == field.exercise }),
              let index = exercise.sets.firstIndex(where: { $0.id == field.set }) else {
            focus = nil
            return
        }
        let valueKind: KeypadField.Kind = exercise.tracksDuration ? .duration : .reps
        if field.kind == .weight {
            self.focus(KeypadField(exercise: exercise.id, set: field.set, kind: valueKind))
        } else if index + 1 < exercise.sets.count {
            self.focus(KeypadField(exercise: exercise.id, set: exercise.sets[index + 1].id, kind: .weight))
        } else {
            focus = nil
        }
    }

    /// Le champ à remplir avant de valider : la charge d'un exercice à charge externe, puis les répétitions ou les secondes.
    /// Les valeurs sont celles que la validation prendrait (la proposition tant que la série n'est pas modifiée).
    private static func missingField(of set: LiveSet, in exercise: LiveExercise) -> KeypadField.Kind? {
        let source = set.isEdited ? (set.weightKg, set.reps, set.durationSeconds)
            : (set.proposed.weightKg, set.proposed.reps, set.proposed.durationSeconds)
        if exercise.loadKind == .external, source.0 == nil { return .weight }
        if exercise.tracksDuration { return source.2 == nil ? .duration : nil }
        return source.1 == nil ? .reps : nil
    }

    private static func value(of kind: KeypadField.Kind, in set: LiveSet) -> Double? {
        switch kind {
        case .weight: set.weightKg
        case .reps: set.reps.map(Double.init)
        case .duration: set.durationSeconds.map(Double.init)
        }
    }

    private static var saveFailure: String {
        String(localized: "Pulse n'a pas pu enregistrer ta séance.", bundle: .module)
    }
}
