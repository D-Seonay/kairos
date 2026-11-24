import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// L'onglet Planning (spec M6 §7, maquette `planning`) : la bande des 7 jours, la carte du jour et son lancement, la semaine en
/// liste avec ses déplacements, puis le mois et la série. Une séance validée s'ouvre d'une touche.
public struct PlanningView: View {
    private let model: PlanningModel
    private let train: TrainModel
    private let onStartSession: (SessionLaunch) -> Void
    private let onResumeSession: () -> Void
    private let onStartRun: ((RunLaunch) -> Void)?
    private let onPlanChanged: () -> Void
    @State private var path: [PlanningDestination] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `train` donne la séance du jour ajustée au score et son lancement, comme l'onglet Séance ; `onStartSession` démarre la
    /// séance rendue ; `onResumeSession` rouvre celle en cours. `onStartRun` démarre la course rendue : sans lui, la carte du jour
    /// n'offre pas « Courir ». `onPlanChanged` dit à l'app qu'un déplacement a changé la semaine, pour relire les autres onglets.
    public init(model: PlanningModel, train: TrainModel, onStartSession: @escaping (SessionLaunch) -> Void,
                onResumeSession: @escaping () -> Void, onStartRun: ((RunLaunch) -> Void)? = nil,
                onPlanChanged: @escaping () -> Void = {}) {
        self.model = model
        self.train = train
        self.onStartSession = onStartSession
        self.onResumeSession = onResumeSession
        self.onStartRun = onStartRun
        self.onPlanChanged = onPlanChanged
    }

    public var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                content(proxy: proxy)
            }
            .pulseScreenBackground(aura: 0.5)
            .hidingNavigationBar()
            .navigationDestination(for: PlanningDestination.self, destination: destination)
        }
        .task { await refresh() }
        // Revenir d'un détail relit la semaine : une séance a pu être corrigée.
        .onChange(of: path) { Task { await refresh() } }
        .confirmationDialog(movingTitle, isPresented: isMoving, titleVisibility: .visible) {
            if let day = model.moving {
                ForEach(model.targets(for: day)) { target in
                    Button("\(model.weekdayName(target.date).capitalized) · \(model.title(of: target))") {
                        Task {
                            await model.swap(day, with: target)
                            await planChanged()
                        }
                    }
                }
            }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) { model.moving = nil }
        } message: {
            Text(String(localized: "Les deux jours échangent leur séance.", bundle: .module))
        }
    }

    private func refresh() async {
        await model.load()
        await train.refresh()
    }

    /// Après un déplacement, la semaine est déjà relue : la séance du jour et son lancement, qui viennent de l'onglet Séance, le
    /// sont à leur tour, puis l'app relit les autres onglets.
    private func planChanged() async {
        await train.refresh()
        onPlanChanged()
    }

    private func content(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                header
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                if model.hasLoaded {
                    loaded(proxy: proxy)
                } else {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Chargement du planning", bundle: .module))
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable { await refresh() }
        .pulseAnnounceError(model.errorMessage)
    }

    /// La bande, la carte du jour, la semaine et l'entrée du mois, une fois la semaine lue : avant, ce serait une semaine vide.
    @ViewBuilder
    private func loaded(proxy: ScrollViewProxy) -> some View {
        // Sept colonnes ne tiennent pas au-delà de `xxxLarge`, et la liste « Cette semaine » donne les mêmes jours en grand.
        WeekStrip(model: model) { day in select(day, proxy: proxy) }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        if let today = model.today {
            TodayPlanCard(model: model, train: train, day: today, onStart: start, onResume: onResumeSession,
                          onStartRun: startRunAction)
        }
        week
        monthEntry
    }

    /// Un jour de la bande ouvre son détail s'il en a un ; sinon la liste « Cette semaine » défile jusqu'à lui.
    private func select(_ day: PlanningDay, proxy: ScrollViewProxy) {
        if let destination = model.destination(for: day) {
            path.append(destination)
        } else {
            PulseMotion.perform(.default, reduceMotion: reduceMotion) { proxy.scrollTo(day.id, anchor: .center) }
        }
    }

    /// Le bouton « Courir » de la carte du jour, seulement quand l'app sait lancer une course.
    private var startRunAction: (() -> Void)? {
        guard onStartRun != nil else { return nil }
        return { startRun() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.weekTitle)
                .pulseEyebrow(PulsePalette.text2)
            Text(String(localized: "Planning", bundle: .module))
                .font(PulseFont.title(.largeTitle, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 8) {
            PulseSectionHeader(String(localized: "Cette semaine", bundle: .module))
            ForEach(model.days) { day in
                WeekDayRow(model: model, day: day, onOpen: model.destination(for: day).map { destination in { path.append(destination) } },
                           onKeepPlanned: { keepPlanned(day) })
                    .id(day.id)
            }
            if model.overview?.hasUserMoves == true {
                Button(String(localized: "Rétablir la semaine type", bundle: .module)) {
                    Task {
                        await model.restoreWeek()
                        await planChanged()
                    }
                }
                .buttonStyle(PulseDesignSystem.LinkButtonStyle())
                .accessibilityIdentifier(PlanningIdentifiers.restoreWeek)
            }
            Text(String(localized: "Touche longue sur un jour à venir pour le déplacer.", bundle: .module))
                .font(.caption)
                .foregroundStyle(PulsePalette.muted)
        }
    }

    @ViewBuilder
    private var monthEntry: some View {
        let button = Button { path.append(.month) } label: {
            PulseRow(systemImage: "flame", title: String(localized: "Mois et série", bundle: .module), detail: streakText)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(PlanningIdentifiers.month)
        if let streak = model.streak, let week = streak.currentWeek {
            button.accessibilityLabel(PlanningText.monthEntrySpoken(weeks: streak.streak, count: week.count, target: week.target))
        } else {
            button
        }
    }

    private var streakText: String {
        guard let streak = model.streak, let week = streak.currentWeek else { return "" }
        return PlanningText.streakRow(weeks: streak.streak, count: week.count, target: week.target)
    }

    /// Lance la séance du jour de l'onglet Séance ; avec une séance déjà en cours, la rouvre.
    private func start() {
        if train.activeSessionTitle != nil {
            onResumeSession()
        } else if let launch = train.launchToday() {
            onStartSession(launch)
        }
    }

    /// Lance la course du jour, comme « Courir » de l'onglet Séance ; avec une séance déjà en cours, la rouvre.
    private func startRun() {
        if train.activeSessionTitle != nil {
            onResumeSession()
        } else {
            onStartRun?(train.runLaunch())
        }
    }

    /// « Garder le jour prévu » : rend le jour à la semaine type, puis relit la séance du jour.
    private func keepPlanned(_ day: PlanningDay) {
        Task {
            await model.keepPlanned(day)
            await planChanged()
        }
    }

    @ViewBuilder
    private func destination(_ destination: PlanningDestination) -> some View {
        switch destination {
        case .session(let id):
            SessionDetailView(model: model.sessionDetailModel(sessionID: id))
        case .activity(let id):
            ActivityDetailView(model: model.activityDetailModel(sessionID: id))
        case .month:
            MonthView(model: model.monthModel())
        }
    }

    private var movingTitle: String {
        guard let day = model.moving else { return "" }
        return String(localized: "Déplacer « \(model.title(of: day)) »", bundle: .module)
    }

    private var isMoving: Binding<Bool> {
        Binding(get: { model.moving != nil }, set: { if !$0 { model.moving = nil } })
    }
}

extension View {
    /// L'onglet a son propre en-tête : la barre de navigation n'apparaît que sur les écrans poussés. Sans effet sur Mac.
    func hidingNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
