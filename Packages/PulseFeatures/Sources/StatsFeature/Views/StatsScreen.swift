import NightFeature
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// L'onglet Stats (spec M7 §5 et §12, maquette `stats`) : l'en-tête, le segment des cinq vues, les puces de période, puis la
/// vue choisie. La période est gardée d'un lancement à l'autre ; toucher un record de force pousse la fiche de l'exercice.
public struct StatsScreen: View {
    private let model: StatsModel
    /// La période choisie, gardée par sa valeur brute ; poussée dans le modèle à l'apparition et à chaque choix.
    @AppStorage("stats.period") private var storedPeriod = StatsPeriod.month.rawValue
    @State private var openedExercise: ExerciseReference?
    /// Vrai quand l'écran Nuit est poussé depuis la carte Sommeil de la vue Biométrie.
    @State private var showsNights = false
    /// Le modèle de l'écran Nuit, créé au toucher du lien : il garde la nuit affichée tant que l'écran reste poussé.
    @State private var nightModel: NightModel?

    public init(model: StatsModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            content
                .pulseScreenBackground(aura: 0.5)
                .hidingNavigationBar()
                .navigationDestination(item: $openedExercise) { reference in
                    ExerciseSheetView(model: progressionSheet(for: reference))
                }
                .navigationDestination(isPresented: $showsNights) {
                    if let nightModel { NightScreen(model: nightModel) }
                }
        }
        .onAppear(perform: applyStoredPeriod)
        .onChange(of: storedPeriod) { applyStoredPeriod() }
        .task {
            if !model.hasLoaded { await model.load() }
        }
    }

    /// La fiche d'un exercice, ouverte sur l'onglet Progression (spec M7 §10).
    private func progressionSheet(for reference: ExerciseReference) -> ExerciseSheetModel {
        let sheet = ExerciseSheetModel(environment: model.environment.train, reference: reference)
        sheet.tab = .progression
        return sheet
    }

    /// Pousse l'écran Nuit sur la nuit la plus récente.
    private func openNights() {
        nightModel = NightModel(service: model.environment.nights, initialDay: nil, calendar: model.environment.calendar)
        showsNights = true
    }

    private func applyStoredPeriod() {
        model.period = StatsPeriod(rawValue: storedPeriod) ?? .month
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                header
                StatsViewSegment(model: model)
                ChoicePills(options: StatsPeriod.allCases.map { (value: $0, label: $0.title) }, selection: periodSelection,
                            groupLabel: String(localized: "Période", bundle: .module))
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let snapshot = model.snapshot {
                    section(snapshot)
                } else if !model.hasLoaded {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Chargement des statistiques", bundle: .module))
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable { await model.load() }
        // Sur le conteneur, toujours présent : l'erreur est annoncée à chaque échec, même au texte identique.
        .pulseAnnounceOnce(model.errorMessage, id: model.failureCount, isError: true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(intervalTitle)
                .pulseEyebrow(PulsePalette.text2)
            Text(String(localized: "Statistiques", bundle: .module))
                .font(PulseFont.title(.largeTitle, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(StatsIdentifiers.screen)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// « Du 22 oct. au 20 nov. » : la fenêtre glissante de la période choisie.
    private var intervalTitle: String {
        let calendar = model.environment.calendar
        let interval = model.period.interval(now: model.environment.now(), calendar: calendar)
        let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let start = StatsText.dayMonth(interval.start, calendar: calendar, month: .abbreviated)
        let end = StatsText.dayMonth(last, calendar: calendar, month: .abbreviated)
        return String(localized: "Du \(start) au \(end)", bundle: .module)
    }

    private var periodSelection: Binding<StatsPeriod?> {
        Binding(get: { StatsPeriod(rawValue: storedPeriod) ?? .month },
                set: { if let period = $0 { storedPeriod = period.rawValue } })
    }

    /// La vue choisie, sur la période de la lecture affichée (et non celle demandée, encore en lecture).
    @ViewBuilder
    private func section(_ snapshot: StatsSnapshot) -> some View {
        let window = StatsWindow(period: snapshot.period, now: model.environment.now(), calendar: model.environment.calendar)
        switch model.view {
        case .load:
            LoadSection(load: snapshot.load, window: window)
        case .biometry:
            BiometrySection(biometry: snapshot.biometry, window: window, onOpenNights: openNights)
        case .muscles:
            MusclesSection(muscles: snapshot.muscles, window: window)
        case .attendance:
            AttendanceSection(attendance: snapshot.attendance, window: window)
        case .records:
            RecordsSection(records: snapshot.records, window: window) { openedExercise = $0 }
        }
    }
}

/// Le segment des cinq vues : il défile à l'horizontale quand il ne tient pas (iPhone mini, texte agrandi).
private struct StatsViewSegment: View {
    let model: StatsModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(StatsView.allCases) { view in
                    button(view)
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(PulsePalette.line).frame(height: 1)
        }
    }

    private func button(_ view: StatsView) -> some View {
        let isSelected = model.view == view
        return Button {
            guard !isSelected else { return }
            model.view = view
            PulseHaptics.selection()
        } label: {
            Text(view.title)
                .font(.subheadline.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? PulsePalette.text : PulsePalette.text2)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle().fill(PulsePalette.ink).frame(height: 2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
