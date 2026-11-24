import AppIntents
import LiveSessionFeature
import PulseLiveActivity
import PulseServices
import RunFeature

/// Branche les boutons −30 s, +30 s et Passer de la Live Activity sur le seul service de séance de l'app (spec M4 §5.2) : il
/// enregistre le repos, met l'activité à jour et replanifie la notification ; l'écran ouvert relit ensuite la séance. Les boutons
/// Pause et Reprendre de la Live Activity de course passent de même par le seul service de course (spec V2a §4.4).
@MainActor
final class SessionIntentWiring {
    private let service: ActiveSessionService
    private let runService: RunSessionService
    /// La séance des onglets, posée par la racine ; `nil` avant les onglets ou quand un bouton réveille l'app en arrière-plan.
    weak var coordinator: LiveSessionCoordinator?
    /// La course des onglets, posée par la racine, dans les mêmes cas que `coordinator`.
    weak var runCoordinator: RunCoordinator?

    init(service: ActiveSessionService, runService: RunSessionService) {
        self.service = service
        self.runService = runService
    }

    /// Au lancement, avant qu'une intention ne s'exécute.
    func install() {
        SessionIntentBridge.handler = { control in
            await self.handle(control)
        }
        RunIntentBridge.handler = { control in
            await self.handle(control)
        }
    }

    /// Sans course en cours, le bouton d'une activité périmée ne change rien ; le bandeau et l'écran ouvert relisent la course.
    func handle(_ control: RunControl) async {
        switch control {
        case .pause: await runService.pause()
        case .resume: await runService.resume()
        }
        await runCoordinator?.refresh()
    }

    /// Sans séance en cours, le bouton d'une activité périmée ne change rien.
    func handle(_ control: RestControl) async {
        _ = try? await service.apply(Self.change(for: control))
        await coordinator?.refresh()
    }

    static func change(for control: RestControl) -> LiveSessionChange {
        switch control {
        case .minus30: .restMinus30
        case .plus30: .restPlus30
        case .skip: .skipRest
        }
    }
}

/// Les intentions de la Live Activity, déclarées par l'app qui les exécute.
struct PulseAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [PulseLiveActivityIntents.self]
    }
}
