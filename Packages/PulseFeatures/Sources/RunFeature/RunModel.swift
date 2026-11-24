import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'écran de la course, du départ au récap (spec V2a §4.2, §4.3, §4.5). L'état de la course en cours vient du coordinateur, qui
/// suit le service ; le modèle garde ce qui n'appartient qu'à l'écran : le signal GPS du départ, l'action en cours et l'erreur.
@MainActor
@Observable
public final class RunModel {
    public enum Phase: Equatable {
        case start(RunLaunch)
        case running
        case recap(RunRecapModel)

        public static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case let (.start(left), .start(right)): left == right
            case (.running, .running): true
            case let (.recap(left), .recap(right)): left === right
            default: false
            }
        }
    }

    public private(set) var phase: Phase
    /// Le signal du départ ; `nil` avant la première valeur.
    public private(set) var gps: RunGPSQuality?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?
    /// Mémorisé par appareil : coupé ici, il l'est aussi dans Paramètres.
    public var announcesKilometres: Bool {
        didSet { environment.preferences.setAnnouncesKilometres(announcesKilometres) }
    }

    /// Le flux du signal s'est terminé sans valeur : la localisation est refusée.
    private var previewDenied = false
    /// Parti avant « Prêt » : la distance ne compte qu'à partir des premiers points précis, et le récap le dit.
    private var startedWithoutSignal = false
    @ObservationIgnored private weak var coordinator: RunCoordinator?
    @ObservationIgnored private let environment: RunEnvironment

    init(phase: Phase, coordinator: RunCoordinator) {
        self.phase = phase
        self.coordinator = coordinator
        environment = coordinator.environment
        announcesKilometres = coordinator.environment.preferences.announcesKilometres
    }

    public var calendar: Calendar { environment.calendar }

    /// La course en cours, telle que le coordinateur la suit.
    public var snapshot: RunSnapshot? {
        coordinator?.current
    }

    /// L'objectif affiché : celui du départ, puis celui de la course en cours.
    public var launch: RunLaunch? {
        switch phase {
        case .start(let launch): launch
        case .running: snapshot?.launch
        case .recap: nil
        }
    }

    public var recap: RunRecapModel? {
        if case .recap(let recap) = phase { recap } else { nil }
    }

    public var locationDenied: Bool {
        switch phase {
        case .start: previewDenied
        case .running: snapshot?.locationDenied ?? false
        case .recap: false
        }
    }

    /// La ligne « Localisation refusée : seul le temps est enregistré. », au départ et pendant la course.
    public var locationNotice: String? {
        locationDenied ? RunText.locationDenied : nil
    }

    // MARK: Départ

    /// Suit le signal GPS de l'écran de départ jusqu'au départ ou à l'annulation. Le flux se termine aussitôt, sans valeur, quand
    /// la localisation est refusée.
    public func watchGPS() async {
        guard case .start = phase else { return }
        var received = false
        for await quality in await environment.service.gpsPreview() {
            received = true
            gps = quality
        }
        if !received, !Task.isCancelled, case .start = phase { previewDenied = true }
    }

    /// Arrête le suivi du signal quand l'écran de départ disparaît.
    public func cancelPreview() async {
        await environment.service.cancelPreview()
    }

    /// « Partir » : le signal n'a pas besoin d'être prêt.
    public func start() async {
        guard case .start(let launch) = phase, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        startedWithoutSignal = !previewDenied && gps != .ready
        do {
            let snapshot = try await environment.service.start(launch)
            errorMessage = nil
            coordinator?.showRunning(snapshot)
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu démarrer la course.", bundle: .module)
        }
    }

    /// « Annuler » de l'écran de départ.
    public func cancel() async {
        await environment.service.cancelPreview()
        coordinator?.close()
    }

    // MARK: Course

    public func pause() async {
        guard phase == .running else { return }
        await environment.service.pause()
        coordinator?.update(await environment.service.current())
    }

    public func resume() async {
        guard phase == .running else { return }
        await environment.service.resume()
        coordinator?.update(await environment.service.current())
    }

    /// « Terminer », une fois confirmé : la course est enregistrée et le récap s'ouvre.
    public func finish() async {
        guard phase == .running, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let data = try await environment.service.finish()
            errorMessage = nil
            coordinator?.showRecap(data)
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu terminer la course.", bundle: .module)
        }
    }

    /// Réduit l'écran de course : la course continue, le bandeau « Reprendre la course » la rouvre.
    public func minimize() {
        coordinator?.isPresented = false
    }

    // MARK: Transitions du coordinateur

    func showRunning() {
        phase = .running
    }

    func showRecap(_ data: RunRecapData) {
        let recap = RunRecapModel(data: data, service: environment.service, startedWithoutSignal: startedWithoutSignal)
        recap.onClose = { [weak coordinator] in coordinator?.close() }
        phase = .recap(recap)
    }
}
