import Foundation
import Observation
import PulseServices

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

    /// La séance est restée ouverte plus de 3 h : l'heure de fin proposée, celle de la dernière série plus son repos.
    public struct ForgottenPrompt: Sendable, Equatable {
        public var intent: Intent
        public var suggestedEnd: Date
    }

    public private(set) var confirmation: Confirmation?
    public private(set) var forgotten: ForgottenPrompt?
    public private(set) var recap: RecapModel?
    public private(set) var errorMessage: String?

    @ObservationIgnored private let live: LiveSessionModel
    @ObservationIgnored private var isProceeding = false
    @ObservationIgnored private let onFinished: @MainActor () -> Void

    public init(live: LiveSessionModel, onFinished: @escaping @MainActor () -> Void) {
        self.live = live
        self.onFinished = onFinished
    }

    var calendar: Calendar { live.environment.calendar }

    // MARK: Gestes de l'écran

    /// « Terminer » : une confirmation s'il reste des séries de travail prévues non validées, sinon la suite.
    public func finishTapped() async {
        let remaining = live.session.plannedWorkingSets - live.session.doneWorkingSets
        if remaining > 0 {
            confirmation = .unfinished(remaining: remaining)
        } else {
            await proceed(.finish)
        }
    }

    /// « Abandonner » : toujours une confirmation.
    public func abandonTapped() {
        confirmation = .abandon
    }

    public func cancelConfirmation() {
        confirmation = nil
    }

    /// Le oui de la confirmation en attente.
    public func confirm() async {
        guard let pending = confirmation else { return }
        confirmation = nil
        await proceed(pending == .abandon ? .abandon : .finish)
    }

    /// Le choix de l'alerte de la séance oubliée : l'heure proposée (le choix par défaut) ou celle de maintenant.
    public func chooseEnd(usingSuggestion: Bool) async {
        guard let prompt = forgotten else { return }
        forgotten = nil
        let endedAt = usingSuggestion ? prompt.suggestedEnd : live.environment.now()
        await complete(prompt.intent, endedAt: endedAt)
    }

    /// « Enregistrer » ou « Plus tard » du récap, une fois la séance écrite.
    public func recapSaved() {
        recap = nil
        onFinished()
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: Suite

    /// L'heure de fin : celle que propose le service pour une séance oubliée, sinon maintenant.
    private func proceed(_ intent: Intent) async {
        // Un second appui sur « Terminer » pendant la lecture de l'heure proposée ne rouvre pas la suite.
        guard !isProceeding, forgotten == nil, recap == nil else { return }
        isProceeding = true
        defer { isProceeding = false }
        errorMessage = nil
        if let suggested = await live.environment.service.suggestedEnd() {
            forgotten = ForgottenPrompt(intent: intent, suggestedEnd: suggested)
        } else {
            await complete(intent, endedAt: live.environment.now())
        }
    }

    private func complete(_ intent: Intent, endedAt: Date) async {
        switch intent {
        case .finish:
            let model = RecapModel(service: live.environment.service, endedAt: endedAt)
            recap = model
            await model.load()
        case .abandon:
            do {
                _ = try await live.environment.service.abandon(endedAt: endedAt)
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
