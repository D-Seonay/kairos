import CheckInFeature
import Foundation
import Observation
import PulseDomain
import PulseServices

/// Ce que l'écran de calibration montre : rien encore, la lecture en cours, le score du jour ou le check-in à faire.
public enum CalibrationPhase: Equatable {
    case idle
    case reading(progress: Double)
    case scored(DailyRecovery, BaselineSummary)
    case needsCheckIn(missing: [Factor], baseline: BaselineSummary)
}

/// Le parcours de premier lancement, reprenable : chaque transition enregistre le brouillon du profil et l'étape atteinte.
@MainActor
@Observable
public final class OnboardingModel {
    public internal(set) var step: OnboardingStep = .welcome
    /// Le brouillon du profil, enregistré à chaque étape ; il devient le profil définitif à `finish()`.
    public var profile: UserProfile
    public private(set) var recommendedTemplateID: String?
    public var selectedTemplateID: String?
    /// « Je construis le mien » : aucun programme n'est adopté.
    public var choseCustomProgram = false
    public var notifyWhenScoreReady = true
    public internal(set) var calibration: CalibrationPhase = .idle
    public let checkIn = CheckInForm()
    public private(set) var isFinished = false
    public internal(set) var errorMessage: String?
    /// Faux tant que `start()` n'a pas restauré le brouillon et l'étape : avant, aucune action ne doit écrire le profil.
    public private(set) var hasStarted = false

    @ObservationIgnored let environment: OnboardingEnvironment
    /// Apple Santé ignoré : la calibration passe directement par le check-in.
    @ObservationIgnored var healthSkipped = false
    /// Numéro de la calibration en cours : une lecture périmée (retour arrière, nouvelle lecture) n'écrit plus rien.
    @ObservationIgnored var calibrationGeneration = 0
    /// Vrai pendant l'enregistrement du check-in : observé, le bouton du check-in reste inactif.
    var isSubmittingCheckIn = false
    /// Valeurs d'Apple Santé placées dans le brouillon et pas encore validées à l'étape du profil : le formulaire les montre,
    /// mais elles ne sont ni enregistrées ni synchronisées avant `continueFromProfile()`.
    @ObservationIgnored var unvalidatedHints: HealthProfileHints?

    public init(environment: OnboardingEnvironment) {
        self.environment = environment
        profile = UserProfile(createdAt: environment.now())
    }

    /// Les séances de la semaine : musculation `round(jours × (1 − focus))`, le reste en sorties de course.
    public var weekProposal: (strength: Int, runs: Int) {
        let days = profile.trainingDaysPerWeek
        let strength = min(days, max(0, Int((Double(days) * (1 - profile.focus)).rounded())))
        return (strength, days - strength)
    }

    // MARK: - Reprise

    public func start() async {
        defer { hasStarted = true }
        let stored = try? await environment.profiles.load()
        if let stored, stored.onboardingCompletedAt != nil {
            isFinished = true
            return
        }
        if let stored {
            profile = stored
        }
        step = environment.stepStore.load() ?? .welcome
        if step == .profile, let hints = try? await environment.health.profileHints() {
            // Les propositions d'Apple Santé n'ont pas été enregistrées : on les relit à la reprise.
            prefill(from: hints)
        }
        if step.rawValue >= OnboardingStep.program.rawValue {
            await restoreProgramSelection()
        }
    }

    /// Vrai si un profil terminé est apparu depuis iCloud : le brouillon et son programme sont alors écartés.
    public func checkForRestoredProfile() async -> Bool {
        guard let restored = try? await environment.profiles.load(),
              restored.onboardingCompletedAt != nil, restored.id != profile.id else { return false }
        if let programID = profile.activeProgramID, programID != restored.activeProgramID {
            try? await environment.programs.delete(id: programID)
        }
        try? await environment.profiles.delete(id: profile.id)
        environment.stepStore.clear()
        isFinished = true
        return true
    }

    // MARK: - Étapes

    public func begin() async {
        guard hasStarted else { return }
        errorMessage = nil
        await advance(to: .health)
    }

    public func allowHealth() async {
        errorMessage = nil
        healthSkipped = false
        var hints: HealthProfileHints?
        do {
            try await environment.health.requestAuthorization()
            // La demande est faite : iOS liste désormais Pulse dans Réglages › Santé, quoi que la personne ait répondu.
            environment.once.record(.healthAccessRequest)
            hints = try? await environment.health.profileHints()
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu accéder à Apple Santé. Tu peux continuer sans.", bundle: .module)
        }
        // Le brouillon est enregistré avant de recevoir les propositions : elles restent en mémoire jusqu'à la validation.
        guard await advance(to: .profile) else { return }
        if let hints {
            prefill(from: hints)
        }
    }

    public func skipHealth() async {
        errorMessage = nil
        healthSkipped = true
        await advance(to: .profile)
    }

    public func continueFromProfile() async {
        errorMessage = nil
        let increments = profile.strengthLevel.defaultIncrementsKg
        profile.upperIncrementKg = increments.upper
        profile.lowerIncrementKg = increments.lower
        // Valider l'étape vaut accord pour les valeurs proposées par Apple Santé : elles partent avec le brouillon.
        unvalidatedHints = nil
        await advance(to: .goals)
    }

    public func continueFromGoals() async {
        errorMessage = nil
        recommendedTemplateID = recommendation()
        selectedTemplateID = recommendedTemplateID
        choseCustomProgram = false
        await advance(to: .program)
    }

    /// Adopte le modèle choisi (ou aucun) à la place du programme adopté plus tôt dans ce parcours, puis lance la calibration.
    /// Si le brouillon ne s'enregistre pas, rien ne change : on reste sur l'étape, le programme précédent est conservé.
    public func adoptProgram() async {
        errorMessage = nil
        let previous = profile.activeProgramID
        let adopted: UUID?
        do {
            adopted = try await adoptSelectedTemplate()
        } catch {
            errorMessage = Self.saveFailureMessage
            return
        }
        profile.activeProgramID = adopted
        // L'étape change avant la fin de l'enregistrement qui suit : la lecture est déjà « en cours » pour que la vue ne la relance pas.
        calibration = .reading(progress: 0)
        guard await advance(to: .calibration) else {
            calibration = .idle
            profile.activeProgramID = previous
            if let adopted {
                try? await environment.programs.delete(id: adopted)
            }
            return
        }
        if let previous, previous != adopted {
            do {
                try await environment.programs.delete(id: previous)
            } catch {
                errorMessage = Self.saveFailureMessage
            }
        }
        await calibrate()
    }

    public func finish() async {
        errorMessage = nil
        var granted = false
        if notifyWhenScoreReady {
            granted = await environment.notifications.requestAuthorization()
        }
        profile.morningScoreNotification = notifyWhenScoreReady && granted
        profile.onboardingCompletedAt = environment.now()
        guard await saveDraft() else {
            profile.onboardingCompletedAt = nil
            return
        }
        environment.stepStore.clear()
        isFinished = true
    }

    public func goBack() {
        errorMessage = nil
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        if step == .calibration {
            calibration = .idle
            calibrationGeneration += 1
        }
        step = previous
        environment.stepStore.save(previous)
    }

    // MARK: - Interne

    /// Enregistre le brouillon puis l'étape. Si le brouillon ne s'enregistre pas, on reste sur l'étape courante.
    @discardableResult
    func advance(to next: OnboardingStep) async -> Bool {
        guard await saveDraft() else { return false }
        step = next
        environment.stepStore.save(next)
        return true
    }

    /// Le brouillon est le profil entier, à l'onboarding seul jusqu'à `finish()` : il reste écrit par son `id` avec `save`, et non
    /// avec `update`, qui s'appliquerait au profil de `load()`, c'est-à-dire à un profil terminé restauré depuis iCloud entre-temps.
    func saveDraft() async -> Bool {
        profile.updatedAt = environment.now()
        do {
            try await environment.profiles.save(withoutUnvalidatedHints(profile))
            return true
        } catch {
            errorMessage = Self.saveFailureMessage
            return false
        }
    }

    static var saveFailureMessage: String {
        String(localized: "Pulse n'a pas pu enregistrer ta progression.", bundle: .module)
    }

    private func recommendation() -> String? {
        TemplateRecommender.recommendedID(
            focus: profile.focus, daysPerWeek: profile.trainingDaysPerWeek, templates: environment.library.programTemplates)
    }

    /// Reprise à `.program` ou après : la recommandation vient du brouillon, la sélection du programme déjà adopté (sinon de la
    /// recommandation). « Je construis le mien » n'est retenu qu'une fois la calibration atteinte sans programme.
    private func restoreProgramSelection() async {
        recommendedTemplateID = recommendation()
        var adoptedTemplateID: String?
        if let programID = profile.activeProgramID {
            adoptedTemplateID = try? await environment.programs.program(id: programID)?.templateID
        }
        selectedTemplateID = adoptedTemplateID ?? recommendedTemplateID
        choseCustomProgram = step == .calibration && profile.activeProgramID == nil
    }

    /// Ne remplit que les champs encore vides ; le sexe seulement s'il vaut `.unspecified`. Retient ce qui a été rempli,
    /// pour ne pas l'enregistrer avant la validation de l'étape du profil.
    private func prefill(from hints: HealthProfileHints) {
        var applied = unvalidatedHints ?? HealthProfileHints()
        if profile.sex == .unspecified, let sex = hints.sex {
            profile.sex = sex
            applied.sex = sex
        }
        if profile.birthDate == nil, let birthDate = hints.birthDate {
            profile.birthDate = birthDate
            applied.birthDate = birthDate
        }
        if profile.heightCm == nil, let heightCm = hints.heightCm {
            profile.heightCm = heightCm
            applied.heightCm = heightCm
        }
        if profile.weightKg == nil, let weightKg = hints.weightKg {
            profile.weightKg = weightKg
            applied.weightKg = weightKg
        }
        unvalidatedHints = applied
    }

    /// Le brouillon tel qu'il peut être enregistré : un champ qui porte encore la valeur proposée par Apple Santé, non validée,
    /// repart vide. Une valeur modifiée à la main est gardée.
    private func withoutUnvalidatedHints(_ draft: UserProfile) -> UserProfile {
        guard let hints = unvalidatedHints else { return draft }
        var saved = draft
        if let sex = hints.sex, saved.sex == sex { saved.sex = .unspecified }
        if let birthDate = hints.birthDate, saved.birthDate == birthDate { saved.birthDate = nil }
        if let heightCm = hints.heightCm, saved.heightCm == heightCm { saved.heightCm = nil }
        if let weightKg = hints.weightKg, saved.weightKg == weightKg { saved.weightKg = nil }
        return saved
    }

    /// Enregistre le programme adopté et renvoie son id ; `nil` pour « Je construis le mien » ou un modèle introuvable.
    private func adoptSelectedTemplate() async throws -> UUID? {
        guard !choseCustomProgram,
              let template = environment.library.programTemplates.first(where: { $0.id == selectedTemplateID }) else { return nil }
        let program = ProgramAdopter(library: environment.library).adopt(
            template, equipment: profile.equipmentAccess, painAreas: profile.painAreas,
            restWeekdays: profile.restWeekdays, now: environment.now())
        try await environment.programs.save(program)
        return program.id
    }
}
