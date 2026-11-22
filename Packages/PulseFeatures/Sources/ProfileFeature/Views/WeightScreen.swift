import Charts
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'écran Poids (spec M7 §14), poussé depuis la page Profil : la tendance et la courbe des 90 derniers jours, la dernière masse
/// grasse, « Ajouter une pesée » et les mesures de l'année avec leur source. Une saisie manuelle se modifie au toucher et se
/// supprime par balayage ; une mesure Apple Santé n'a ni l'un ni l'autre.
struct WeightScreen: View {
    @State private var model: WeightModel

    /// `onChanged` part après chaque écriture : la page Profil se recharge.
    init(environment: ProfileEnvironment, onChanged: @escaping @MainActor () async -> Void) {
        _model = State(initialValue: WeightModel(environment: environment, onChanged: onChanged))
    }

    var body: some View {
        @Bindable var model = model
        List {
            if let message = model.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(PulsePalette.surface)
            }
            if let overview = model.overview {
                if overview.measurements.isEmpty {
                    emptyState
                } else {
                    trendSection(overview.trend)
                    addButton
                    measurementsSection(overview)
                }
            } else if !model.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .accessibilityLabel(String(localized: "Chargement des pesées", bundle: .module))
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.load() }
        .pulseAnnounceOnce(model.errorMessage, id: model.failureCount, isError: true)
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(String(localized: "Poids", bundle: .module))
        .pulseInlineTitle()
        .sheet(item: $model.editor, onDismiss: model.editorDismissed) { _ in
            NavigationStack {
                WeighInSheet(model: model)
            }
        }
        .task { await model.load() }
    }

    private var calendar: Calendar { model.environment.calendar }

    // MARK: Tendance

    private func trendSection(_ trend: WeightTrend) -> some View {
        let today = model.environment.now()
        return Section {
            VStack(alignment: .leading, spacing: 12) {
                if let current = trend.current {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ProfileText.weight(current))
                            .font(PulseFont.value(.largeTitle))
                            .foregroundStyle(PulsePalette.text)
                        Text(ProfileText.trendCaption(trend, calendar: calendar, today: today))
                            .font(.caption)
                            .foregroundStyle(PulsePalette.text2)
                        if let change = trend.change30Days {
                            Text(ProfileText.weightChange(change))
                                .font(.subheadline)
                                .foregroundStyle(PulsePalette.text)
                                .padding(.top, 4)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ProfileText.weightTrendSpoken(trend, calendar: calendar, today: today) ?? "")
                } else {
                    ProfileEmptyNote(heading: String(localized: "Pas encore de pesée", bundle: .module),
                                     reason: String(localized: "seule la masse grasse a été mesurée", bundle: .module))
                }
                if let fat = trend.latestBodyFat {
                    Text(String(localized: "Masse grasse \(ProfileText.bodyFat(fat, calendar: calendar, today: today))",
                                bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityLabel(ProfileText.bodyFatLineSpoken(trend, calendar: calendar, today: today) ?? "")
                }
                // Sans aucun jour pesé, la note du dessus suffit : pas de seconde note à la place de la courbe.
                if !trend.days.isEmpty {
                    WeightChart(trend: trend, calendar: calendar, today: today)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var addButton: some View {
        Section {
            Button(String(localized: "Ajouter une pesée", bundle: .module), action: model.startNew)
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
    }

    // MARK: Mesures

    private func measurementsSection(_ overview: BodyOverview) -> some View {
        let today = model.environment.now()
        return Section {
            ForEach(overview.measurements) { measurement in
                let row = MeasurementRow(measurement: measurement, calendar: calendar, today: today)
                if measurement.source == .manual {
                    Button { model.edit(measurement) } label: { row }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await model.delete(measurement) }
                            } label: {
                                Label(String(localized: "Supprimer", bundle: .module), systemImage: "trash")
                            }
                        }
                        .accessibilityHint(String(localized: "Touche pour modifier la pesée", bundle: .module))
                } else {
                    row
                }
            }
        } header: {
            Text(String(localized: "Mesures", bundle: .module))
        } footer: {
            if !overview.hasAppleHealthData {
                Text(Self.healthHint)
            }
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// Sans mesure lue, HealthKit ne dit pas si la lecture est refusée : l'écran renvoie vers Santé (spec M7 §14).
    static var healthHint: String {
        String(localized: "Aucune pesée dans Apple Santé. Vérifie l'accès de Pulse dans Santé → Partage.", bundle: .module)
    }

    // MARK: État vide

    private var emptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                IconChip(systemName: "scalemass", size: 44)
                Text(String(localized: "Pas encore de pesée", bundle: .module))
                    .font(PulseFont.title(.title3, weight: .semibold))
                    .foregroundStyle(PulsePalette.text)
                Text(Self.healthHint)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "Ajouter une pesée", bundle: .module), action: model.startNew)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(PulsePalette.surface)
    }
}

/// Une mesure : sa valeur (« 78,4 kg », « 17,5 % de masse grasse »), sa date et sa source.
private struct MeasurementRow: View {
    let measurement: BodyMeasurement
    let calendar: Calendar
    let today: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// La valeur, la date et la source sur une ligne ; aux tailles d'accessibilité, l'une sous l'autre.
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(ProfileText.measurement(measurement))
                    .font(PulseFont.value(.headline))
                    .foregroundStyle(PulsePalette.text)
                Text(ProfileText.shortDate(measurement.date, calendar: calendar, today: today))
                    .font(.caption)
                    .foregroundStyle(PulsePalette.text2)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(ProfileText.source(measurement.source))
                .font(.caption)
                .foregroundStyle(PulsePalette.text2)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ProfileText.measurementSpoken(measurement, calendar: calendar, today: today))
    }
}

#if DEBUG
/// Prépare l'environnement de l'aperçu (avec deux saisies manuelles en plus des pesées d'Apple Santé) puis pousse l'écran.
private struct WeightPreviewHost: View {
    var withHistory = true
    @State private var environment: ProfileEnvironment?

    var body: some View {
        NavigationStack {
            if let environment {
                WeightScreen(environment: environment) {}
            } else {
                ProgressView()
            }
        }
        .task {
            let environment = await ProfilePreviewSupport.environment(withHistory: withHistory)
            if withHistory {
                try? await environment.body.addManual(weightKg: 77.9, date: ProfilePreviewSupport.day(-1, hour: 7))
                try? await environment.body.addManual(weightKg: 78.2, date: ProfilePreviewSupport.day(0, hour: 7))
            }
            self.environment = environment
        }
        .preferredColorScheme(.light)
    }
}

/// La feuille de pesée ouverte sur une nouvelle pesée.
private struct WeighInPreviewHost: View {
    @State private var model: WeightModel?

    var body: some View {
        NavigationStack {
            if let model {
                WeighInSheet(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            let model = WeightModel(environment: await ProfilePreviewSupport.environment(withHistory: false)) {}
            model.startNew()
            self.model = model
        }
        .preferredColorScheme(.light)
    }
}

#Preview("Poids") {
    WeightPreviewHost()
}

#Preview("Poids, très grand texte") {
    WeightPreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Nouvelle pesée, très grand texte") {
    WeighInPreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Poids, sans mesure") {
    WeightPreviewHost(withHistory: false)
}

#Preview("Nouvelle pesée") {
    WeighInPreviewHost()
}
#endif
