import PulseDomain
import WidgetFeature
import WidgetKit

/// Écrit l'instantané du jour dans le groupe d'apps et demande au widget de se recharger quand il a changé.
/// Le widget est un confort : une erreur d'écriture ou l'absence du groupe d'apps ne remonte jamais à l'app.
struct AppGroupWidgetPublisher: WidgetPublishing {
    private let file: WidgetSnapshotFile?

    /// `nil` sans groupe d'apps (appareil non signé pour lui) : rien n'est publié.
    init(file: WidgetSnapshotFile?) {
        self.file = file
    }

    func publish(_ snapshot: WidgetSnapshot) async {
        guard let changed = try? file?.write(snapshot), changed else { return }
        reloadTimelines()
    }

    func clear() async {
        guard let file else { return }
        try? file.delete()
        reloadTimelines()
    }

    private func reloadTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: RecoveryWidgetContent.kind)
    }
}
