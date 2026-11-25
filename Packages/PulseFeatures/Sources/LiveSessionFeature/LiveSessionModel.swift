import Foundation
import Observation
import PhotosFeature
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
    /// Les photos de la séance, prises sous l'identifiant de la séance enregistrée (`ActiveSessionService.finish` le garde). Le
    /// récap reprend ce modèle. `nil` sans service des photos et pour une saisie après coup : la fabrique des séances passées ne
    /// reçoit pas le dépôt des photos, qui ne serait pas nettoyé si la saisie était annulée. Les photos s'ajoutent alors depuis
    /// le détail de la séance enregistrée.
    public let photos: SessionPhotosModel?

    @ObservationIgnored let environment: LiveSessionEnvironment
    @ObservationIgnored private let haptics: LiveSessionHaptics
    @ObservationIgnored private var pendingChanges = 0
    /// Le début du repos dont la fin a déjà fait vibrer : +30 s ne la fait pas vibrer deux fois. L'écran s'en sert aussi pour
    /// annoncer la fin du repos à VoiceOver.
    private(set) var reachedRestEnd: Date?
    /// La dernière seconde du compte à rebours qui a fait vibrer : la `TimelineView` peut redessiner deux fois la même seconde.
    @ObservationIgnored private var lastCountdown: RestCountdownMark?

    private struct RestCountdownMark: Equatable {
        var restStartedAt: Date
        var second: Int
    }

    init(session: LiveSession, environment: LiveSessionEnvironment, haptics: LiveSessionHaptics = .system) {
        self.session = session
        self.environment = environment
        self.haptics = haptics
        photos = session.isPastEntry ? nil : environment.train.sessionPhotos.map {
            SessionPhotosModel(service: $0, sessionID: session.id, calendar: environment.calendar)
        }
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
    /// **(choix du constructeur)**. Valider la série que le clavier édite le fait passer au même champ de la série suivante
    /// non validée de l'exercice, ou le ferme s'il n'y en a plus.
    public func tap(set id: UUID) async {
        guard let exercise = session.exercises.first(where: { $0.sets.contains { $0.id == id } }),
              let set = exercise.sets.first(where: { $0.id == id }) else { return }
        if set.completedAt != nil {
            if await perform(.unvalidate(exercise: exercise.id, set: id)) { haptics.soft() }
        } else if let missing = Self.missingField(of: set, in: exercise) {
            focus(KeypadField(exercise: exercise.id, set: id, kind: missing))
        } else if await perform(.validate(exercise: exercise.id, set: id)) {
            haptics.validation()
            celebrateCompletion(of: exercise.id)
            if let focus, focus.set == id { moveFocus(afterValidating: focus) }
        }
    }

    /// Une validation qui termine la séance la fête (`sessionDone`) ; une qui termine seulement l'exercice, `exerciseDone`.
    private func celebrateCompletion(of exercise: UUID) {
        if session.isDone {
            haptics.sessionDone()
        } else if session.exercises.first(where: { $0.id == exercise })?.isDone == true {
            haptics.exerciseDone()
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
    /// l'exercice, puis ferme le clavier ; les autres touches modifient la valeur. `onInput` reçoit le tampon avant et après la
    /// touche, avant l'enregistrement : l'écran le dit à VoiceOver sans attendre la sauvegarde.
    public func keypadKey(_ key: KeypadInput.Key, onInput: ((_ before: String, _ after: String) -> Void)? = nil) async {
        guard let focus else { return }
        if key == .next {
            advance(from: focus)
            return
        }
        let before = keypad.text
        let value = keypad.apply(key)
        // Une touche sans effet (virgule sur des répétitions, effacement d'un champ vide) ne modifie pas la série.
        guard keypad.text != before else { return }
        onInput?(before, keypad.text)
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
        if let rpe, !RoutineRules.rpe.contains(rpe) || (rpe * 2).rounded() != rpe * 2 { return }
        guard let exercise = exerciseID(containing: set) else { return }
        haptics.light()
        await perform(.edit(exercise: exercise, set: set, rpe: .some(rpe)))
    }

    public func setType(_ type: SetType, set: UUID) async {
        guard let exercise = exerciseID(containing: set) else { return }
        if await perform(.setType(exercise: exercise, set: set, type)) { haptics.tick() }
    }

    public func addSet(exercise: UUID) async {
        if await perform(.addSet(exercise: exercise)) { haptics.tick() }
    }

    public func deleteSet(_ set: UUID) async {
        guard let exercise = exerciseID(containing: set) else { return }
        if focus?.set == set { focus = nil }
        if await perform(.deleteSet(exercise: exercise, set: set)) { haptics.soft() }
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
        if await perform(.removeExercise(exercise)) { haptics.soft() }
    }

    public func moveExercise(_ exercise: UUID, by offset: Int) async {
        await perform(.moveExercise(exercise, by: offset))
    }

    public func setNote(_ note: String?, exercise: UUID) async {
        await perform(.setNote(exercise: exercise, note))
    }

    /// L'incrément de charge de l'exercice : la séance le prend tout de suite, ses réglages pour la suite, comme l'échauffement.
    public func setIncrement(_ incrementKg: Double, exercise: UUID) async {
        guard let reference = session.exercises.first(where: { $0.id == exercise })?.exercise,
              await perform(.setIncrement(exercise: exercise, incrementKg)) else { return }
        // Le tampon vaut la valeur enregistrée : rouvrir le champ lui donne le nouvel incrément.
        if let focus, focus.exercise == exercise { self.focus(focus) }
        do {
            try await environment.service.saveIncrement(incrementKg, for: reference)
        } catch {
            errorMessage = Self.saveFailure
        }
    }

    /// Le nombre de séries d'échauffement de l'exercice : la séance le prend tout de suite, ses réglages pour la suite.
    public func setWarmupCount(_ count: Int?, exercise: UUID) async {
        guard let reference = session.exercises.first(where: { $0.id == exercise })?.exercise,
              await perform(.setWarmupCount(exercise: exercise, count)) else { return }
        do {
            try await environment.service.saveWarmupCount(count, for: reference)
        } catch {
            errorMessage = Self.saveFailure
        }
    }

    /// La charge des séries de travail restantes de l'exercice (calculateur de disques).
    public func setRemainingLoad(_ weightKg: Double, exercise: UUID) async {
        await perform(.setRemainingLoad(exercise: exercise, weightKg: weightKg))
    }

    // MARK: Remplacer

    /// Les alternatives à l'exercice, planifiées avec leur charge proposée (spec M4 §19.3) ; aucune si la lecture échoue.
    public func replacementOptions(for exercise: UUID, reason: ReplacementReason) async -> [ReplacementOption] {
        do {
            return try await environment.service.replacementOptions(for: exercise, reason: reason)
        } catch {
            errorMessage = Self.saveFailure
            return []
        }
    }

    /// Remplace l'exercice par une alternative déjà planifiée.
    public func replace(_ exercise: UUID, with replacement: LiveExercise) async {
        focus(nil)
        await perform(.replaceExercise(exercise, with: replacement))
    }

    /// Remplace l'exercice par un exercice choisi dans la bibliothèque.
    public func replace(_ exercise: UUID, withPicked reference: ExerciseReference, reason: ReplacementReason) async {
        do {
            guard let replacement = try await environment.service.replacement(for: exercise, with: reference,
                                                                              reason: reason) else { return }
            await replace(exercise, with: replacement)
        } catch {
            errorMessage = Self.saveFailure
        }
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

    /// L'écran appelle cette méthode à chaque seconde du repos : un tic sec pour chacune des trois dernières (3, 2, 1), une seule
    /// fois par seconde et par repos, pour lever la tête du téléphone avant la vibration longue.
    public func restCountdown(secondsLeft: Int) {
        guard let rest = session.rest, (1...Self.countdownSeconds).contains(secondsLeft),
              reachedRestEnd != rest.startedAt else { return }
        let mark = RestCountdownMark(restStartedAt: rest.startedAt, second: secondsLeft)
        guard lastCountdown != mark else { return }
        lastCountdown = mark
        haptics.tick()
    }

    static let countdownSeconds = 3

    /// L'écran appelle cette méthode quand le repos arrive à sa fin : une vibration longue, une seule fois par repos.
    public func didReachRestEnd() {
        guard let rest = session.rest, reachedRestEnd != rest.startedAt else { return }
        reachedRestEnd = rest.startedAt
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

    /// La série du clavier vient d'être validée : le même champ de la série suivante non validée de l'exercice, sinon le clavier
    /// se ferme.
    private func moveFocus(afterValidating field: KeypadField) {
        guard let exercise = session.exercises.first(where: { $0.id == field.exercise }),
              let index = exercise.sets.firstIndex(where: { $0.id == field.set }),
              let next = exercise.sets[(index + 1)...].first(where: { $0.completedAt == nil }) else {
            focus = nil
            return
        }
        self.focus(KeypadField(exercise: exercise.id, set: next.id, kind: field.kind))
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

// MARK: - Abandon

extension LiveSessionModel {
    /// Après un abandon : une séance abandonnée sans série validée n'est pas enregistrée (`ActiveSessionService.abandon`), et
    /// ses photos ne doivent pas rester dans iCloud. L'abandon les a supprimées, mais un ajout encore en cours pouvait en écrire
    /// une après lui : le modèle des photos arrête ses ajouts et supprime ce qui reste. Une séance enregistrée garde ses photos.
    func discardPhotosIfUnsaved(after abandoned: WorkoutSession) async {
        guard abandoned.sets.isEmpty else { return }
        await photos?.discard()
    }
}
