import Foundation
import Observation
import PulseServices
import SupplementsFeature

/// La suite de « Terminer » et d'« Abandonner » (spec M4 §14.6, §16) : la confirmation, l'heure de fin d'une séance oubliée, puis
/// le récap (terminer) ou l'abandon. Chaque étape est une propriété que la vue lit ; `onFinished` ferme la séance une fois
/// enregistrée ou abandonnée.
@MainActor
@Observable
public final class FinishFlowModel {
    public enum Intent: Sendable, Equatable {
        case finish
        case abandon
    }

    /// Une confirmation en attente.
    public enum Confirmation: Sendable, Equatable {
        /// « Il reste N séries prévues » : terminer quand même ?
        case unfinished(remaining: Int)
        case abandon
    }

    /// La séance est restée ouverte plus de 3 h : l'heure de fin proposée, celle de la dernière série plus son repos. À la
    /// reprise, l'autre choix est de continuer la séance plutôt que de la clore maintenant.
    public struct ForgottenPrompt: Sendable, Equatable {
        public var intent: Intent
        public var suggestedEnd: Date
        public var isOnResume = false
    }

    public private(set) var confirmation: Confirmation?
    public private(set) var forgotten: ForgottenPrompt?
    public private(set) var recap: RecapModel?
    public private(set) var errorMessage: String?

    @ObservationIgnored private let live: LiveSessionModel
    @ObservationIgnored private var isProceeding = false
    /// « Continuer la séance » à la reprise : la dernière action de la séance et l'heure de la réponse. Tant que la séance n'a
    /// pas bougé, la question n'est pas reposée, sauf si plus de 3 h passent encore sans action après la réponse : c'est un
    /// nouvel oubli.
    @ObservationIgnored private var continued: (lastActionAt: Date, answeredAt: Date)?
    @ObservationIgnored private let onFinished: @MainActor () -> Void
    @ObservationIgnored private let onMinimize: (@MainActor () -> Void)?

    /// `onMinimize` ferme l'écran sans finir la séance (`LiveSessionCoordinator.minimize`) ; `nil` sans bandeau pour la
    /// reprendre, comme une saisie après coup.
    public init(live: LiveSessionModel, onFinished: @escaping @MainActor () -> Void,
                onMinimize: (@MainActor () -> Void)? = nil) {
        self.live = live
        self.onFinished = onFinished
        self.onMinimize = onMinimize
    }

    var calendar: Calendar { live.environment.calendar }

    /// Vrai quand l'écran peut se réduire : la séance continue et son bandeau « Reprendre » la rouvre.
    public var canMinimize: Bool { onMinimize != nil }

    // MARK: Gestes de l'écran

    /// « Terminer » : une confirmation s'il reste des séries de travail prévues non validées, sinon la suite.
    public func finishTapped() async {
        guard isIdle else { return }
        let remaining = live.session.plannedWorkingSets - live.session.doneWorkingSets
        if remaining > 0 {
            confirmation = .unfinished(remaining: remaining)
        } else {
            isProceeding = true
            defer { isProceeding = false }
            await start(.finish)
        }
    }

    /// « Abandonner » : toujours une confirmation.
    public func abandonTapped() {
        guard isIdle else { return }
        confirmation = .abandon
    }

    /// La confirmation se ferme sans choix (le système peut la fermer sans passer par un bouton) : la séance reste telle quelle.
    public func cancelConfirmation() {
        confirmation = nil
    }

    /// Le oui de la confirmation en attente. L'état est lu et effacé tout de suite : la fermeture de la fenêtre qui suit ne le
    /// retrouve plus. La tâche rendue est la suite, que les tests attendent.
    @discardableResult
    public func confirm() -> Task<Void, Never>? {
        guard let pending = confirmation, !isProceeding else { return nil }
        confirmation = nil
        let intent: Intent = pending == .abandon ? .abandon : .finish
        return run { await $0.start(intent) }
    }

    /// La séance oubliée vient d'être rouverte (spec M4 §16) : l'alerte propose de la clore à `suggestedEnd`, ce qui mène au
    /// récap, ou de continuer, ce que fait aussi sa fermeture sans bouton (`cancelForgotten()`). Déjà affichée, ou écartée
    /// depuis moins de 3 h sans action, elle n'est pas reposée.
    public func offerToClose(at suggestedEnd: Date) {
        guard isIdle, !isStillContinued else { return }
        forgotten = ForgottenPrompt(intent: .finish, suggestedEnd: suggestedEnd, isOnResume: true)
    }

    /// Vrai quand « Continuer la séance » vaut encore : la séance n'a pas bougé depuis, et la réponse a moins de 3 h.
    private var isStillContinued: Bool {
        guard let continued, live.session.lastActionAt == continued.lastActionAt else { return false }
        return live.environment.now().timeIntervalSince(continued.answeredAt) <= ActiveSessionService.forgottenAfter
    }

    /// Le choix de l'alerte de la séance oubliée : l'heure proposée (le choix par défaut) ou celle de maintenant. Même règle que
    /// `confirm()` : le choix est pris avant la fermeture de l'alerte.
    @discardableResult
    public func chooseEnd(usingSuggestion: Bool) -> Task<Void, Never>? {
        guard let prompt = forgotten, !isProceeding else { return nil }
        forgotten = nil
        let endedAt = usingSuggestion ? prompt.suggestedEnd : live.environment.now()
        return run { await $0.complete(prompt.intent, endedAt: endedAt) }
    }

    /// L'alerte de la séance oubliée se ferme sans bouton, ou « Continuer la séance » à la reprise : la séance reste ouverte,
    /// rien n'est enregistré ni abandonné. C'est le choix sûr, car ni l'heure proposée ni celle de maintenant n'ont été
    /// voulues ; « Terminer » rouvre l'alerte.
    public func cancelForgotten() {
        if forgotten?.isOnResume == true { continued = (live.session.lastActionAt, live.environment.now()) }
        forgotten = nil
    }

    /// Le chevron de l'en-tête : l'écran se ferme, la séance continue et son bandeau « Reprendre » apparaît. Sans effet pendant
    /// une étape de la suite (confirmation, alerte, récap).
    public func minimize() {
        guard isIdle, let onMinimize else { return }
        onMinimize()
    }

    /// « Enregistrer » ou « Enregistrer sans noter » du récap, une fois la séance écrite.
    public func recapSaved() {
        recap = nil
        onFinished()
    }

    /// « Revenir à la séance » du récap : rien n'est encore écrit, la séance reprend telle quelle et « Terminer » ouvrira un
    /// récap neuf. Sans effet pendant un enregistrement.
    public func resumeFromRecap() {
        guard let recap, !recap.isSaving else { return }
        self.recap = nil
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: Suite

    /// Aucune étape en cours : ni confirmation, ni alerte, ni récap, ni suite qui s'exécute.
    private var isIdle: Bool {
        !isProceeding && confirmation == nil && forgotten == nil && recap == nil
    }

    /// Lance la suite, qui tient `isProceeding` du geste jusqu'à son terme : un second « Terminer » ou « Abandonner » attend.
    private func run(_ work: @escaping @MainActor (FinishFlowModel) async -> Void) -> Task<Void, Never> {
        isProceeding = true
        return Task { [self] in
            defer { isProceeding = false }
            await work(self)
        }
    }

    /// L'heure de fin : celle que propose le service pour une séance oubliée, celle saisie pour une séance passée, sinon
    /// maintenant.
    private func start(_ intent: Intent) async {
        errorMessage = nil
        if let suggested = await live.environment.service.suggestedEnd() {
            forgotten = ForgottenPrompt(intent: intent, suggestedEnd: suggested)
        } else {
            await complete(intent, endedAt: live.session.pastEndedAt ?? live.environment.now())
        }
    }

    private func complete(_ intent: Intent, endedAt: Date) async {
        switch intent {
        case .finish:
            // Les compléments de la séance ne concernent qu'une séance faite aujourd'hui, pas une saisie après coup.
            let supplements = live.session.isPastEntry ? nil : live.environment.supplements.map(SupplementsModel.init)
            // Les photos prises pendant la séance sont dans le modèle de la séance live : le récap le reprend.
            let model = RecapModel(service: live.environment.service, endedAt: endedAt, supplements: supplements,
                                   photos: live.photos)
            recap = model
            await model.load()
        case .abandon:
            do {
                let abandoned = try await live.environment.service.abandon(endedAt: endedAt)
                await live.discardPhotosIfUnsaved(after: abandoned)
                onFinished()
            } catch {
                errorMessage = String(localized: "Pulse n'a pas pu abandonner la séance.", bundle: .module)
            }
        }
    }
}

// MARK: - Textes

extension FinishFlowModel {
    /// « 08:41 », en heure du calendrier de l'app.
    nonisolated static func timeText(_ date: Date, calendar: Calendar) -> String {
        let style = Date.FormatStyle(locale: Locale(identifier: "fr_FR"), calendar: calendar, timeZone: calendar.timeZone)
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
        return date.formatted(style)
    }

    /// « Il reste 1 série prévue », « Il reste 3 séries prévues ».
    nonisolated static func remainingText(_ remaining: Int) -> String {
        remaining == 1 ? String(localized: "Il reste 1 série prévue", bundle: .module)
            : String(localized: "Il reste \(remaining) séries prévues", bundle: .module)
    }
}
