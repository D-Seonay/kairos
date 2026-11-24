import Foundation
import Observation
import PulseDomain
import PulseServices

/// Prépare, présente et reprend l'unique course (spec V2a §4.2, §4.3, §5.4) ; alimente le bandeau « Reprendre la course » et les
/// alertes de reprise et d'oubli de l'app. Un seul `RunModel` existe par course, du départ au récap.
@MainActor
@Observable
public final class RunCoordinator {
    /// La course en cours dans ce processus, suivie par le flux des états du service ; `nil` au départ et au récap.
    public private(set) var current: RunSnapshot?
    public var isPresented = false
    /// Une course interrompue à enregistrer ou supprimer : l'app l'affiche en alerte.
    public private(set) var recovery: RunRecoveryOffer?
    /// Le dernier déplacement d'une course sans doute oubliée : l'app propose d'y terminer la course.
    public private(set) var forgottenEnd: Date?
    public var errorMessage: String?

    @ObservationIgnored let environment: RunEnvironment
    @ObservationIgnored private var runModel: RunModel?
    @ObservationIgnored private var subscription: Task<Void, Never>?
    @ObservationIgnored private var isRefreshing = false

    public init(environment: RunEnvironment) {
        self.environment = environment
    }

    /// Ouvre l'écran de départ. Une course déjà en cours est présentée à la place ; une séance de musculation en cours ou une
    /// course interrompue en attente l'empêchent.
    public func prepare(_ launch: RunLaunch) {
        if current != nil {
            isPresented = true
            return
        }
        guard !environment.isStrengthSessionActive() else {
            errorMessage = RunText.strengthSessionActive
            return
        }
        guard recovery == nil else {
            errorMessage = String(localized: "Une course interrompue attend : enregistre-la ou supprime-la d'abord.",
                                  bundle: .module)
            return
        }
        errorMessage = nil
        runModel = RunModel(phase: .start(launch), coordinator: self)
        isPresented = true
    }

    /// Au lancement et au retour au premier plan. Une course de ce processus reprend son état et, ouverte, propose d'être
    /// terminée si elle semble oubliée. Sinon, le brouillon d'une course précédente est rattaché si sa séance HealthKit tourne
    /// encore (l'écran de course se rouvre), ou proposé à l'enregistrement.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let service = environment.service
        if let snapshot = await service.current() {
            showRunning(snapshot)
            if isPresented { forgottenEnd = await service.forgottenEnd() }
            return
        }
        // La course suivie s'est terminée hors de l'écran : il se ferme au lieu d'attendre un état qui ne viendra plus.
        if current != nil { close() }
        guard let offer = await service.recoveryOffer() else {
            recovery = nil
            return
        }
        if offer.isStillRecording, let snapshot = await service.reattach() {
            recovery = nil
            showRunning(snapshot)
            isPresented = true
        } else {
            recovery = offer
        }
    }

    /// « Reprendre » du bandeau : rouvre l'écran de course, avec l'alerte d'oubli si la course semble oubliée.
    public func resume() async {
        guard current != nil else { return }
        isPresented = true
        forgottenEnd = await environment.service.forgottenEnd()
    }

    /// Le modèle de la course, créé une fois par course. Sans course préparée, celui d'une course libre.
    public func model() -> RunModel {
        if let runModel { return runModel }
        let model = RunModel(phase: current == nil ? .start(.free()) : .running, coordinator: self)
        runModel = model
        return model
    }

    // MARK: Reprise et oubli

    /// « Enregistrer » de l'alerte de course interrompue : la course est enregistrée jusqu'à son dernier point, puis son récap
    /// s'ouvre pour le RPE et la note.
    public func saveInterruptedRun() async {
        do {
            let data = try await environment.service.saveInterrupted()
            recovery = nil
            showRecap(data)
        } catch {
            recovery = nil
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer la course interrompue.", bundle: .module)
        }
    }

    /// « Supprimer » de l'alerte de course interrompue : rien n'est enregistré.
    public func discardInterruptedRun() async {
        await environment.service.discard()
        recovery = nil
    }

    /// « Terminer » de l'alerte d'oubli : la course s'arrête à son dernier déplacement et le récap s'ouvre.
    public func finishAtForgottenEnd() async {
        guard let end = forgottenEnd else { return }
        forgottenEnd = nil
        do {
            showRecap(try await environment.service.finish(at: end))
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu terminer la course.", bundle: .module)
        }
    }

    /// « Continuer » de l'alerte d'oubli.
    public func dismissForgotten() {
        forgottenEnd = nil
    }

    // MARK: Cycle de la course

    /// La course tourne : son état est suivi et le modèle passe à l'écran de course.
    func showRunning(_ snapshot: RunSnapshot) {
        current = snapshot
        model().showRunning()
        if subscription == nil { subscribe() }
    }

    /// Un état relu directement auprès du service, sans attendre le flux (pause et reprise depuis l'écran).
    func update(_ snapshot: RunSnapshot?) {
        current = snapshot
    }

    /// La course est terminée : son récap s'ouvre.
    func showRecap(_ data: RunRecapData) {
        endRunning()
        forgottenEnd = nil
        model().showRecap(data)
        isPresented = true
    }

    /// Récap enregistré ou supprimé, ou départ annulé : plus d'écran ni de modèle.
    func close() {
        endRunning()
        runModel = nil
        isPresented = false
    }

    private func endRunning() {
        subscription?.cancel()
        subscription = nil
        current = nil
    }

    /// Suit le flux des états du service : un seul abonné, terminé avec la course. Une valeur arrivée après l'arrêt du suivi est
    /// ignorée.
    private func subscribe() {
        let service = environment.service
        subscription = Task { [weak self] in
            let snapshots = await service.snapshots()
            for await snapshot in snapshots {
                guard !Task.isCancelled, let self else { return }
                self.current = snapshot
            }
        }
    }
}
