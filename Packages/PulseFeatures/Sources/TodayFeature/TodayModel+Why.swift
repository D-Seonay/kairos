extension TodayModel {
    /// Pousse l'écran « Pourquoi ». Sans effet tant qu'il n'y a pas de score du jour à expliquer.
    func showWhy() {
        guard why != nil else { return }
        isShowingWhy = true
    }

    /// Referme l'écran « Pourquoi » : un lien du widget ou du contrôle ramène à l'accueil lui-même.
    public func closeWhy() {
        isShowingWhy = false
    }

    /// « Rétablir la séance d'origine » quand la séance ajustée est celle du jour, « Revenir à l'ajustée » sinon ; puis revient
    /// à l'accueil, qui montre la séance choisie.
    func toggleOriginalSessionFromWhy() async {
        await chooseOriginalSession(session?.status == .adjusted)
        isShowingWhy = false
    }
}
