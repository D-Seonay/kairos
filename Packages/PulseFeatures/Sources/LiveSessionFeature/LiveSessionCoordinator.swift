import Foundation
import Observation
import PulseDomain
import PulseServices

/// Démarre, reprend et présente l'unique séance en direct (spec M4 §14.1, §16), et alimente le bandeau « Reprendre la séance »
/// de l'accueil et de l'onglet Séance. Un seul `LiveSessionModel` existe par séance.
@MainActor
@Observable
public final class LiveSessionCoordinator {
    /// La séance enregistrée, pour le bandeau « Reprendre la séance » ; `nil` sans séance en cours.
    public private(set) var current: LiveSession?
    public var isPresented = false
    public private(set) var errorMessage: String?
    /// Un avertissement affiché une seule fois (notifications refusées).
    public private(set) var notice: String?

    @ObservationIgnored private let environment: LiveSessionEnvironment
    @ObservationIgnored private var liveModel: LiveSessionModel?
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var hasRequestedAuthorization = false

    public init(environment: LiveSessionEnvironment) {
        self.environment = environment
    }

    /// Relit la séance enregistrée : au lancement et au retour au premier plan. Le modèle ouvert reprend les changements faits
    /// ailleurs (boutons de la Live Activity) ; une séance finie ailleurs ferme l'écran.
    public func refresh() async {
        guard !isStarting else { return }
        let stored = await environment.service.current()
        current = stored
        if let stored {
            liveModel?.sync(with: stored)
        } else {
            liveModel = nil
            isPresented = false
        }
    }

    /// Présente la séance en cours si elle existe, sinon en démarre une. Un second appel pendant un démarrage est ignoré. Une
    /// séance neuve demande l'autorisation des notifications (une fois par lancement) et signale un refus une fois ; présenter
    /// une séance déjà en cours n'y touche pas.
    public func start(_ launch: SessionLaunch) async {
        guard !isStarting else { return }
        isStarting = true
        let isFresh = await begin(launch)
        isStarting = false
        // La séance existe avant la demande système, et le garde n'est pas tenu pendant qu'elle s'affiche.
        if isFresh { await requestNotificationsOnce() }
    }

    /// Présente la séance en cours ou en démarre une ; vrai si elle vient d'être créée.
    private func begin(_ launch: SessionLaunch) async -> Bool {
        if current != nil {
            isPresented = true
            return false
        }
        do {
            current = try await environment.service.start(launch)
            liveModel = nil
            errorMessage = nil
            isPresented = true
            return true
        } catch ActiveSessionError.alreadyInProgress {
            // Une séance enregistrée que le bandeau n'a pas encore montrée : on la reprend.
            current = await environment.service.current()
            isPresented = current != nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu démarrer la séance.", bundle: .module)
        }
        return false
    }

    public func resume() {
        guard current != nil else { return }
        isPresented = true
    }

    /// « Abandonner » du bandeau : garde les séries validées. Une séance laissée ouverte plus de 3 h se clôt à l'heure proposée
    /// (spec M4 §16), sinon à maintenant.
    public func abandonFromBanner() async {
        guard current != nil else { return }
        let endedAt = await environment.service.suggestedEnd() ?? environment.now()
        do {
            _ = try await environment.service.abandon(endedAt: endedAt)
            didFinish()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu abandonner la séance.", bundle: .module)
        }
    }

    /// Le modèle de la séance en cours, créé une fois. Sans séance, une séance vide : l'écran n'est présenté qu'avec une séance.
    public func model() -> LiveSessionModel {
        if let liveModel { return liveModel }
        let now = environment.now()
        let session = current ?? LiveSession(title: "", startedAt: now, lastActionAt: now)
        let model = LiveSessionModel(session: session, environment: environment)
        liveModel = model
        return model
    }

    /// La séance est terminée ou abandonnée : plus de bandeau, plus d'écran, plus de modèle.
    public func didFinish() {
        current = nil
        liveModel = nil
        isPresented = false
    }

    public func dismissNotice() {
        notice = nil
    }

    private func requestNotificationsOnce() async {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        guard !(await environment.notifications.requestAuthorization()) else { return }
        notice = String(localized: """
            Notifications désactivées : la fin du repos ne sonnera pas écran verrouillé. Tu peux les activer dans Réglages.
            """, bundle: .module)
    }
}
