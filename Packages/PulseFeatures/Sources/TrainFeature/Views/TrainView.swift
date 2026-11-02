import PulseDesignSystem
import SwiftUI

/// Un écran poussé depuis l'onglet « Séance ».
enum TrainDestination: Hashable {
    case routine(UUID)
    case library
    case history
    case hevyImport
}

/// L'onglet « Séance » : la tuile Musculation (qui renvoie à l'accueil pour démarrer), la tuile Course, « Mes routines »,
/// puis la bibliothèque d'exercices, l'historique et l'import Hevy, poussés dans sa pile de navigation.
public struct TrainView: View {
    private let model: TrainModel
    private let onOpenToday: () -> Void

    /// `onOpenToday` affiche l'accueil, où la séance du jour se démarre.
    public init(model: TrainModel, onOpenToday: @escaping () -> Void = {}) {
        self.model = model
        self.onOpenToday = onOpenToday
    }

    public var body: some View {
        NavigationStack {
            content
                .background(PulsePalette.background)
                .hidingNavigationBar()
                .navigationDestination(for: TrainDestination.self, destination: destination)
        }
        // Relu à chaque apparition de l'onglet : l'accueil a pu enregistrer le score du jour entre-temps.
        .task { await model.refresh() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                TrainHeader()
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                TrainTiles(model: model, onOpenToday: onOpenToday)
                routines
                entries
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable { await model.refresh() }
    }

    private var routines: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: String(localized: "Mes routines", bundle: .module))
            if model.routines.isEmpty {
                Text(String(localized: "Aucun programme actif pour l'instant.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            }
            ForEach(model.routines) { routine in
                NavigationLink(value: TrainDestination.routine(routine.day.id)) {
                    RoutineRow(routine: routine)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var entries: some View {
        VStack(spacing: 10) {
            EntryRow(destination: .library, systemImage: "book.closed",
                     title: String(localized: "Bibliothèque d'exercices", bundle: .module),
                     detail: String(localized: "Fiches, consignes et tes exercices perso", bundle: .module),
                     identifier: TrainIdentifiers.library)
            EntryRow(destination: .history, systemImage: "clock.arrow.circlepath",
                     title: String(localized: "Historique", bundle: .module),
                     detail: String(localized: "Tes séances passées et tes records", bundle: .module),
                     identifier: TrainIdentifiers.history)
            EntryRow(destination: .hevyImport, systemImage: "square.and.arrow.down",
                     title: String(localized: "Importer depuis Hevy", bundle: .module),
                     detail: String(localized: "Ton historique, depuis un export CSV", bundle: .module),
                     identifier: TrainIdentifiers.hevyImport)
        }
    }

    @ViewBuilder
    private func destination(_ destination: TrainDestination) -> some View {
        switch destination {
        case .routine:
            // Tâche 15 : l'éditeur de la routine.
            pending(String(localized: "Routine", bundle: .module))
        case .library:
            // Tâche 14 : la bibliothèque d'exercices.
            pending(String(localized: "Bibliothèque d'exercices", bundle: .module))
        case .history:
            // Tâche 16 : l'historique des séances.
            pending(String(localized: "Historique", bundle: .module))
        case .hevyImport:
            // Tâche 17 : l'import Hevy.
            pending(String(localized: "Importer depuis Hevy", bundle: .module))
        }
    }

    private func pending(_ title: String) -> some View {
        ComingSoonView(title: title, milestone: "M4")
            .background(PulsePalette.background)
            .navigationTitle(title)
    }
}

/// « Séance » et sa ligne d'accroche.
private struct TrainHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Séance", bundle: .module))
                .font(.title.weight(.heavy))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            Text(String(localized: "Ce que ton corps peut encaisser aujourd'hui", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(PulsePalette.text)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Une ligne d'entrée vers un écran de l'onglet : icône, titre, détail, chevron.
private struct EntryRow: View {
    let destination: TrainDestination
    let systemImage: String
    let title: String
    let detail: String
    let identifier: String

    var body: some View {
        NavigationLink(value: destination) {
            ObsidianCard {
                HStack(spacing: 12) {
                    TileIcon(systemName: systemImage, foreground: PulsePalette.text2, background: PulsePalette.surface2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(PulsePalette.text)
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PulsePalette.muted)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

private extension View {
    /// L'onglet a son propre en-tête : la barre de navigation n'apparaît que sur les écrans poussés. Sans effet sur Mac.
    func hidingNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
