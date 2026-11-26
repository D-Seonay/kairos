import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Un écran poussé depuis l'onglet « Séance ».
enum TrainDestination: Hashable {
    /// L'éditeur de la routine `day` du programme `program`.
    case routine(program: UUID, day: UUID)
    /// L'éditeur de la course `day` du programme `program`.
    case run(program: UUID, day: UUID)
    case programEditor
    case library
    case history
    /// Le détail de la séance passée `id`.
    case session(UUID)
    case hevyImport
}

/// L'onglet « Séance » : la tuile Musculation (« Démarrer »), la tuile Course,
/// « Mes routines » (« Lancer » ou « Courir », « Mon programme », « + Nouvelle »), puis la bibliothèque d'exercices, l'historique,
/// « Séance libre », « Courir », « Saisir une séance passée » et l'import Hevy. Lancer une séance la rend à l'app, qui ouvre
/// l'écran en direct (« Courir », sur la tuile Course ou dans l'entrée, rend de même la course à lancer) ; s'il y a déjà une
/// séance en cours, l'onglet propose de la reprendre. Le bandeau « Reprendre la séance » est celui de l'app, au-dessus des
/// onglets. Une séance passée se saisit à côté de celle en cours.
public struct TrainView: View {
    private let model: TrainModel
    private let onOpenToday: () -> Void
    private let onStartSession: (SessionLaunch) -> Void
    private let onResumeSession: () -> Void
    private let onEnterPastSession: (SessionLaunch) -> Void
    private let onStartRun: (RunLaunch) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [TrainDestination] = []
    @State private var creationFailed = false
    @State private var offersResume = false
    @State private var isEnteringPast = false
    /// La séance passée rendue par le formulaire : elle s'ouvre une fois la feuille fermée, deux présentations ne se
    /// chevauchant pas.
    @State private var pendingPastLaunch: SessionLaunch?

    /// `onOpenToday` affiche l'accueil ; `onStartSession` démarre la séance rendue ; `onResumeSession` rouvre celle en cours ;
    /// `onEnterPastSession` ouvre la saisie de la séance passée rendue ; `onStartRun` démarre la course rendue.
    public init(model: TrainModel, onOpenToday: @escaping () -> Void, onStartSession: @escaping (SessionLaunch) -> Void,
                onResumeSession: @escaping () -> Void, onEnterPastSession: @escaping (SessionLaunch) -> Void,
                onStartRun: @escaping (RunLaunch) -> Void = { _ in }) {
        self.model = model
        self.onOpenToday = onOpenToday
        self.onStartSession = onStartSession
        self.onResumeSession = onResumeSession
        self.onEnterPastSession = onEnterPastSession
        self.onStartRun = onStartRun
    }

    public var body: some View {
        NavigationStack(path: $path) {
            content
                .pulseScreenBackground(aura: 0.6)
                .hidingNavigationBar()
                .navigationDestination(for: TrainDestination.self, destination: destination)
        }
        // Relu à chaque apparition de l'onglet : l'accueil a pu enregistrer le score du jour entre-temps.
        .task { await model.refresh() }
        // Revenir d'un éditeur relit le programme : la séance du jour et les routines ont pu changer.
        .onChange(of: path) { Task { await model.refresh() } }
        .sheet(isPresented: $isEnteringPast, onDismiss: openPendingPastSession) {
            NavigationStack {
                PastSessionForm(model: model) { pendingPastLaunch = $0 }
            }
        }
        .confirmationDialog(String(localized: "Une séance est déjà en cours", bundle: .module), isPresented: $offersResume,
                            titleVisibility: .visible) {
            Button(String(localized: "Reprendre la séance", bundle: .module), action: onResumeSession)
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: {
            if let title = model.activeSessionTitle {
                Text(String(localized: "« \(title) » est en cours : reprends-la avant d'en lancer une autre.", bundle: .module))
            }
        }
    }

    private func openPendingPastSession() {
        guard let launch = pendingPastLaunch else { return }
        pendingPastLaunch = nil
        onEnterPastSession(launch)
    }

    /// Lance `launch` ; avec une séance déjà en cours, propose de la reprendre à la place.
    private func start(_ launch: SessionLaunch?) {
        guard let launch else { return }
        if model.activeSessionTitle == nil {
            onStartSession(launch)
        } else {
            offersResume = true
        }
    }

    /// Lance la course du jour ou une course libre ; avec une séance de musculation en cours, propose de la reprendre à la place.
    private func startRun() {
        if model.activeSessionTitle == nil {
            onStartRun(model.runLaunch())
        } else {
            offersResume = true
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                // Pas de bandeau « Reprendre » ici : celui de l'app, au-dessus des onglets, le montre déjà, avec « Abandonner ».
                TrainHeader()
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                TrainTiles(model: model, onOpenToday: onOpenToday,
                           onStart: model.launchToday() == nil ? nil : { start(model.launchToday()) },
                           onStartRun: startRun)
                routines
                entries
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable { await model.refresh() }
        .pulseAnnounceError(model.errorMessage)
        .pulseAnnounceError(creationErrorMessage)
    }

    private var creationErrorMessage: String? {
        creationFailed ? String(localized: "Pulse n'a pas pu créer la routine.", bundle: .module) : nil
    }

    private var routines: some View {
        VStack(alignment: .leading, spacing: 10) {
            routinesHeader
            if let message = creationErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.bad)
            }
            if model.showsNoProgram {
                Text(String(localized: "Aucun programme actif pour l'instant.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            }
            ForEach(model.routines) { routine in
                routineRow(routine)
            }
        }
    }

    /// « Mes routines », puis « Mon programme » et « + Nouvelle » en pastilles ; dessous aux tailles d'accessibilité.
    private var routinesHeader: some View {
        PulseSectionHeader(String(localized: "Mes routines", bundle: .module)) {
            NavigationLink(value: TrainDestination.programEditor) {
                Text(String(localized: "Mon programme", bundle: .module))
            }
            .buttonStyle(PillButtonStyle())
            .accessibilityIdentifier(TrainIdentifiers.programLink)
            if model.program != nil {
                Button(action: createRoutine) {
                    Label(String(localized: "Nouvelle", bundle: .module), systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .accessibilityLabel(String(localized: "Nouvelle routine", bundle: .module))
                .accessibilityIdentifier(TrainIdentifiers.routineCreate)
            }
        }
    }

    /// « Lancer » démarre une routine de musculation, « Courir » une course : sa course GPS, avec son objectif.
    private func routineRow(_ routine: RoutineSummary) -> some View {
        let dayID = routine.day.id
        let isStrength = routine.day.kind == .strength
        return RoutineRow(routine: routine, programID: model.program?.id, onLaunch: {
            if isStrength {
                start(model.launch(routine: dayID))
            } else {
                startRun(routine: dayID)
            }
        })
    }

    /// Lance la course `dayID` de « Mes routines » ; avec une séance de musculation en cours, propose de la reprendre à la place.
    private func startRun(routine dayID: UUID) {
        guard let launch = model.runLaunch(routine: dayID) else { return }
        if model.activeSessionTitle == nil {
            onStartRun(launch)
        } else {
            offersResume = true
        }
    }

    /// Crée une routine vide dans le programme actif et ouvre son éditeur.
    private func createRoutine() {
        Task {
            // Remis à zéro avant chaque essai : un échec répété change de nouveau l'état et est annoncé.
            creationFailed = false
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
            PulseSectionHeader(String(localized: "Aller plus loin", bundle: .module))
            EntryRow(destination: .library, systemImage: "book.closed",
                     title: String(localized: "Bibliothèque d'exercices", bundle: .module),
                     detail: String(localized: "Fiches, consignes et tes exercices perso", bundle: .module),
                     identifier: TrainIdentifiers.library)
            EntryRow(destination: .history, systemImage: "clock.arrow.circlepath",
                     title: String(localized: "Historique", bundle: .module),
                     detail: String(localized: "Tes séances passées et tes records", bundle: .module),
                     identifier: TrainIdentifiers.history)
            EntryButton(systemImage: "figure.strengthtraining.traditional",
                        title: String(localized: "Séance libre", bundle: .module),
                        detail: String(localized: "Sans routine : tu ajoutes les exercices au fil de la séance", bundle: .module),
                        identifier: TrainIdentifiers.freeSession) { start(model.freeLaunch()) }
            EntryButton(systemImage: "figure.run",
                        title: String(localized: "Courir", bundle: .module),
                        detail: String(localized: "Ta course du jour, ou une course libre avec le GPS", bundle: .module),
                        identifier: TrainIdentifiers.freeRun, action: startRun)
            EntryButton(systemImage: "calendar.badge.clock",
                        title: String(localized: "Saisir une séance passée", bundle: .module),
                        detail: String(localized: "Une séance faite sans Pulse, avec sa date et sa durée", bundle: .module),
                        identifier: TrainIdentifiers.pastSession) { isEnteringPast = true }
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
        case .run(let program, let day):
            RunDayEditorView(model: model.runDayEditorModel(programID: program, dayID: day))
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
            HevyImportFlow(model: model.hevyImportModel(), onShowHistory: { path = [.history] }, onFinish: { path = [] })
        }
    }
}

/// « Séance » et sa ligne d'accroche.
private struct TrainHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Ce que ton corps peut encaisser aujourd'hui", bundle: .module))
                .pulseEyebrow(PulsePalette.text2)
            Text(String(localized: "Séance", bundle: .module))
                .font(PulseFont.title(.largeTitle, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            PulseRow(systemImage: systemImage, title: title, detail: detail)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

/// Une ligne d'entrée qui fait une action au lieu d'ouvrir un écran.
private struct EntryButton: View {
    let systemImage: String
    let title: String
    let detail: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PulseRow(systemImage: systemImage, title: title, detail: detail)
        }
        .buttonStyle(PressableButtonStyle())
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
