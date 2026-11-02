/// Une porte : `pass()` suspend l'appelant jusqu'à `open()`, et le test peut attendre qu'un appelant soit arrivé devant elle.
/// Copie de celle de `TodayFeatureTests` : les cibles de test ne partagent pas de fichiers.
actor Gate {
    private var isOpen = false
    private var arrivals = 0
    private var held: [CheckedContinuation<Void, Never>] = []
    private var watchers: [CheckedContinuation<Void, Never>] = []

    func pass() async {
        arrivals += 1
        let toWake = watchers
        watchers = []
        toWake.forEach { $0.resume() }
        guard !isOpen else { return }
        await withCheckedContinuation { held.append($0) }
    }

    func waitForArrival(_ count: Int = 1) async {
        while arrivals < count {
            await withCheckedContinuation { watchers.append($0) }
        }
    }

    func open() {
        isOpen = true
        let toWake = held
        held = []
        toWake.forEach { $0.resume() }
    }
}
