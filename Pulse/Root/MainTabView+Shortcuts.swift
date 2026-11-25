import SwiftUI

/// Les demandes des raccourcis Siri que les onglets traitent dès qu'ils sont là, au lancement à froid compris : l'écran
/// « Pourquoi » du score du jour et le départ de la course du jour. Une demande remplacée par une autre (`task(id:)` annule la
/// précédente) n'ouvre plus rien.
extension MainTabView {
    /// « Pourquoi » depuis le score lu par Siri : l'accueil relu, puis son écran « Pourquoi ». Sans score du jour à expliquer,
    /// l'accueil reste simplement affiché.
    func openPendingWhy() async {
        guard router.pendingWhy else { return }
        router.pendingWhy = false
        await refreshToday()
        guard !Task.isCancelled else { return }
        today.openWhy()
    }

    /// « Lancer une course » : comme le contrôle « Séance du jour », l'accueil d'abord relu (il calcule le score du jour et ses
    /// ajustements), puis l'onglet Séance relu, puis l'écran de départ de la course du jour ajustée, sinon d'une course libre ;
    /// la course en cours si elle existe. Une séance de musculation en cours l'empêche, avec le message habituel. Un écran de
    /// course déjà présenté n'est pas remplacé.
    func startPendingRun() async {
        guard router.pendingRunStart else { return }
        router.pendingRunStart = false
        if run.current == nil {
            await refreshToday()
            await train.refresh()
            await waitWhile { train.isRefreshing }
        }
        guard !Task.isCancelled, !run.isPresented else { return }
        run.prepare(train.runLaunch())
    }

    /// Relit l'accueil ; une lecture déjà en cours (lancement à froid, retour au premier plan) fait revenir `refresh()` tout de
    /// suite : on l'attend.
    private func refreshToday() async {
        await today.refresh()
        await waitWhile { today.isLoading }
    }

    /// Attend que `condition` devienne fausse, cinq secondes au plus ; s'arrête aussitôt si la tâche est annulée.
    private func waitWhile(_ condition: () -> Bool) async {
        var waits = 0
        while condition(), waits < 50, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            waits += 1
        }
    }
}
