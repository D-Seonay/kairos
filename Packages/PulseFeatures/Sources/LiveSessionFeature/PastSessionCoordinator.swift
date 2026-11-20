import Foundation
import Observation
import PulseDomain
import PulseServices

/// Présente la saisie d'une séance passée (spec M4 §19.4) : le même écran que la séance en direct, sur le service des séances
/// passées (`ActiveSessionService.pastSessions`), sans bandeau ni reprise. Elle peut s'ouvrir pendant une séance en cours.
@MainActor
@Observable
public final class PastSessionCoordinator {
    public var isPresented = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let environment: LiveSessionEnvironment
    @ObservationIgnored private var liveModel: LiveSessionModel?
    @ObservationIgnored private var flowModel: FinishFlowModel?
    @ObservationIgnored private var isStarting = false

    /// `environment.service` est le service des séances passées, pas celui de la séance en direct.
    public init(environment: LiveSessionEnvironment) {
        self.environment = environment
    }

    /// Planifie la séance passée et ouvre l'écran de saisie. Une saisie laissée en plan (écran fermé sans enregistrer ni
    /// annuler) est remplacée.
    public func start(_ launch: SessionLaunch) async {
        guard !isStarting, launch.past != nil else { return }
        isStarting = true
        defer { isStarting = false }
        if (await environment.service.current()) != nil {
            _ = try? await environment.service.abandon(endedAt: environment.now())
        }
        do {
            let session = try await environment.service.start(launch)
            liveModel = LiveSessionModel(session: session, environment: environment)
            flowModel = nil
            errorMessage = nil
            isPresented = true
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu ouvrir la saisie.", bundle: .module)
        }
    }

    /// Le modèle de la saisie en cours. Sans saisie, une séance vide : l'écran n'est présenté qu'avec une saisie.
    public func model() -> LiveSessionModel {
        if let liveModel { return liveModel }
        let now = environment.now()
        let model = LiveSessionModel(session: LiveSession(title: "", startedAt: now, lastActionAt: now, pastEndedAt: now),
                                     environment: environment)
        liveModel = model
        return model
    }

    /// La suite de « Terminer » et d'« Annuler la saisie », créée une fois avec son modèle.
    public func finishFlow() -> FinishFlowModel {
        if let flowModel { return flowModel }
        let flow = FinishFlowModel(live: model(), onFinished: { [weak self] in self?.didFinish() })
        flowModel = flow
        return flow
    }

    /// La séance est enregistrée ou la saisie annulée : plus d'écran, plus de modèle.
    public func didFinish() {
        isPresented = false
        liveModel = nil
        flowModel = nil
    }

    public func dismissError() {
        errorMessage = nil
    }
}
