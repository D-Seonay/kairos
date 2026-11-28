import PulseDomain
import WidgetFeature
import WidgetKit

/// Écrit l'instantané du jour et l'ambiance choisie dans le groupe d'apps, et demande aux widgets de se recharger quand l'un des
/// deux a changé. Le widget est un confort : une erreur d'écriture ou l'absence du groupe d'apps ne remonte jamais à l'app.
struct AppGroupWidgetPublisher: WidgetPublishing {
    private let file: WidgetSnapshotFile?
    private let theme: WidgetThemeStore

    /// `file` vaut `nil` sans groupe d'apps (appareil non signé pour lui) : aucun instantané n'est publié.
    init(file: WidgetSnapshotFile?, theme: WidgetThemeStore = .appGroup()) {
        self.file = file
        self.theme = theme
    }

    func publish(_ snapshot: WidgetSnapshot) async {
        let changed: Bool
        do {
            changed = try file?.write(snapshot) ?? false
        } catch {
            logger.failure("Instantané du widget non écrit", error)
            return
        }
        guard changed else { return }
        reloadTimelines()
    }

    func publishTheme(_ theme: Theme) async {
        guard self.theme.write(theme) else { return }
        reloadTimelines()
    }

    func clear() async {
        theme.clear()
        do {
            try file?.delete()
        } catch {
            logger.failure("Instantané du widget non effacé", error)
        }
        reloadTimelines()
    }

    private func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
