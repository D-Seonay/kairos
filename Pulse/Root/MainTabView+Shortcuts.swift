import SwiftUI

/// Les demandes des raccourcis Siri que les onglets traitent dès qu'ils sont là, au lancement à froid compris : l'écran
/// « Pourquoi » du score du jour et le départ de la course du jour.
extension MainTabView {
    /// « Pourquoi » depuis le score lu par Siri : l'accueil relu, puis son écran « Pourquoi ». Sans score du jour à expliquer,
    /// l'accueil reste simplement affiché.
    func openPendingWhy() async {
        guard router.pendingWhy else { return }
        router.pendingWhy = false
        await today.refresh()
        // Une lecture déjà en cours fait revenir `refresh()` tout de suite : on l'attend, quelques secondes au plus.
        var waits = 0
        while today.isLoading, waits < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            waits += 1
        }
        today.openWhy()
    }

    /// « Lancer une course » : l'écran de départ de la course du jour, ajustée comme sur l'accueil, sinon d'une course libre ; la
    /// course en cours si elle existe. Une séance de musculation en cours l'empêche, avec le message habituel.
    func startPendingRun() async {
        guard router.pendingRunStart else { return }
        router.pendingRunStart = false
        if run.current == nil {
            await train.refresh()
            var waits = 0
            while train.isRefreshing, waits < 50 {
                try? await Task.sleep(for: .milliseconds(100))
                waits += 1
            }
        }
        run.prepare(train.runLaunch())
    }
}
