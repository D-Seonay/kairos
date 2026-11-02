import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Un écran poussé depuis l'onglet « Séance ».
enum TrainDestination: Hashable {
    /// L'éditeur de la routine `day` du programme `program`.
    case routine(program: UUID, day: UUID)
    case programEditor
    case library
    case history
    /// Le détail de la séance passée `id`.
    case session(UUID)
    case hevyImport
}

/// L'onglet « Séance » : la tuile Musculation (qui renvoie à l'accueil pour démarrer), la tuile Course, « Mes routines »
/// (avec « Mon programme » et « + Nouvelle »), puis la bibliothèque d'exercices, l'historique et l'import Hevy, poussés dans
/// sa pile de navigation.
public struct TrainView: View {
    private let model: TrainModel
    private let onOpenToday: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [TrainDestination] = []
    @State private var creationFailed = false

    /// `onOpenToday` affiche l'accueil, où la séance du jour se démarre.
    public init(model: TrainModel, onOpenToday: @escaping () -> Void = {}) {
        self.model = model
        self.onOpenToday = onOpenToday
    }

    public var body: some View {
        NavigationStack(path: $path) {
            content
                .background(PulsePalette.background)
                .hidingNavigationBar()
                .navigationDestination(for: TrainDestination.self, destination: destination)
        }
        // Relu à chaque apparition de l'onglet : l'accueil a pu enregistrer le score du jour entre-temps.
        .task { await model.refresh() }
        // Revenir d'un éditeur relit le programme : la séance du jour et les routines ont pu changer.
        .onChange(of: path) { Task { await model.refresh() } }
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
            routinesHeader
            if creationFailed {
                Text(String(localized: "Pulse n'a pas pu créer la routine.", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.bad)
            }
            if model.routines.isEmpty {
                Text(String(localized: "Aucun programme actif pour l'instant.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            }
            ForEach(model.routines) { routine in
                routineLink(routine)
            }
        }
    }

    /// « Mes routines », puis « Mon programme » et « + Nouvelle » ; à côté, ou dessous aux tailles d'accessibilité.
    private var routinesHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            SectionTitle(text: String(localized: "Mes routines", bundle: .module))
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            NavigationLink(value: TrainDestination.programEditor) {
                HeaderAction(text: String(localized: "Mon programme", bundle: .module))
            }
            .accessibilityIdentifier(TrainIdentifiers.programLink)
            if model.program != nil {
                Button(action: createRoutine) {
                    HeaderAction(text: String(localized: "+ Nouvelle", bundle: .module))
                }
                .accessibilityLabel(String(localized: "Nouvelle routine", bundle: .module))
                .accessibilityIdentifier(TrainIdentifiers.routineCreate)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func routineLink(_ routine: RoutineSummary) -> some View {
        if routine.day.kind == .run {
            // Les courses ne se modifient pas avant M6.
            RoutineRow(routine: routine)
        } else if let programID = model.program?.id {
            NavigationLink(value: TrainDestination.routine(program: programID, day: routine.day.id)) {
                RoutineRow(routine: routine)
            }
            .buttonStyle(.plain)
        }
    }

    /// Crée une routine vide dans le programme actif et ouvre son éditeur.
    private func createRoutine() {
        Task {
            do {
                let id = try await model.addRoutine(named: String(localized: "Nouvelle routine", bundle: .module))
                guard let programID = model.program?.id else { return }
                creationFailed = false
                path.append(.routine(program: programID, day: id))
            } catch {
                creationFailed = true
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
        case .routine(let program, let day):
            RoutineEditorView(model: model.routineEditorModel(programID: program, dayID: day))
        case .programEditor:
            ProgramEditorView(model: model.programEditorModel())
        case .library:
            LibraryView(model: model.libraryModel(mode: .browse))
        case .history:
            HistoryView(model: model.historyModel())
        case .session(let id):
            SessionDetailView(model: model.sessionDetailModel(sessionID: id)) { program, day in
                path.append(.routine(program: program, day: day))
            }
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

/// Le texte d'un lien d'en-tête de section, accentué, avec une cible d'au moins 44 pt.
private struct HeaderAction: View {
    let text: String
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(PulsePalette.accent(for: theme).accent))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
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
