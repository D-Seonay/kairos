import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Le récap de fin de séance (spec M4 §17, maquette `recap`) : le bilan, les records battus, les muscles travaillés, l'effort
/// global ressenti, la note, puis « Enregistrer » et « Plus tard ». Il n'a pas de bouton de fermeture : on en sort en
/// enregistrant. `onSaved` est appelé une fois la séance écrite.
public struct RecapView: View {
    private let model: RecapModel
    private let calendar: Calendar
    private let onSaved: () -> Void
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(model: RecapModel, calendar: Calendar, onSaved: @escaping () -> Void) {
        self.model = model
        self.calendar = calendar
        self.onSaved = onSaved
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let recap = model.recap {
                    header(recap)
                    stats(recap)
                    if !recap.beatenRecords.isEmpty { records(recap.beatenRecords) }
                    if !recap.setsPerGroup.isEmpty { muscles(recap) }
                    effort()
                    noteField
                } else if model.errorMessage == nil {
                    ProgressView().padding(.top, 80)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PulsePalette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .preferredColorScheme(.dark)
    }

    // MARK: Bilan

    private func header(_ recap: SessionRecap) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Color(PulsePalette.accent(for: theme).accent))
                .accessibilityHidden(true)
            Text(String(localized: "Séance terminée", bundle: .module))
                .font(.title2.weight(.heavy))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            Text(Self.subtitle(title: recap.title, endedAt: recap.endedAt, calendar: calendar))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func stats(_ recap: SessionRecap) -> some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            stat(PulseFormat.duration(minutes: recap.durationMinutes), String(localized: "Durée", bundle: .module))
            stat(PulseFormat.decimal(recap.tonnageKg, maxFractionDigits: 1), String(localized: "kg soulevés", bundle: .module))
            stat("\(recap.workingSets)", String(localized: "Séries", bundle: .module))
            stat("\(recap.beatenRecords.count)", Self.recordsTitle(recap.beatenRecords.count),
                 color: recap.beatenRecords.isEmpty ? PulsePalette.text : PulsePalette.gold)
        }
    }

    private func stat(_ value: String, _ name: String, color: Color = PulsePalette.text) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.heavy).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulsePalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(value)
    }

    private func records(_ records: [BeatenRecord]) -> some View {
        card(title: Self.recordsTitle(records.count)) {
            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                Label {
                    Text(record.text).font(.subheadline).foregroundStyle(PulsePalette.text)
                } icon: {
                    Image(systemName: "trophy.fill").foregroundStyle(PulsePalette.gold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Muscles

    private func muscles(_ recap: SessionRecap) -> some View {
        let largest = max(1, recap.setsPerGroup.map(\.1).max() ?? 1)
        return card(title: String(localized: "Muscles travaillés", bundle: .module), detail: String(localized: "séries", bundle: .module)) {
            MuscleMapView(levels: MuscleIntensity.levels(weights: recap.muscleWeights),
                          label: Self.musclesLabel(recap.setsPerGroup), height: 200)
                .frame(maxWidth: .infinity)
            ForEach(Array(recap.setsPerGroup.enumerated()), id: \.offset) { _, entry in
                groupBar(group: entry.0, count: entry.1, fraction: Double(entry.1) / Double(largest))
            }
        }
    }

    private func groupBar(group: MuscleGroup, count: Int, fraction: Double) -> some View {
        HStack(spacing: 10) {
            Text(group.localizedName)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text)
                .frame(width: 96, alignment: .leading)
            GeometryReader { proxy in
                Capsule()
                    .fill(PulsePalette.surface2)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color(PulsePalette.accent(for: theme).accent))
                            .frame(width: proxy.size.width * fraction)
                    }
            }
            .frame(height: 8)
            Text("\(count)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(PulsePalette.text)
                .frame(minWidth: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(group.localizedName)
        .accessibilityValue(Self.setsText(count))
    }

    // MARK: Effort et note

    private func effort() -> some View {
        card(title: String(localized: "Effort global ressenti", bundle: .module), detail: model.effortText) {
            Slider(value: Binding(get: { Double(model.rpe) }, set: { model.rpe = Int($0.rounded()) }),
                   in: Double(RecapModel.rpeRange.lowerBound)...Double(RecapModel.rpeRange.upperBound), step: 1)
                .tint(Color(PulsePalette.accent(for: theme).accent))
                .accessibilityLabel(String(localized: "Effort global ressenti", bundle: .module))
                .accessibilityValue(model.effortSpokenText)
                .accessibilityIdentifier(LiveSessionIdentifiers.recapRPE)
            HStack {
                Text(String(localized: "1 très facile", bundle: .module))
                Spacer()
                Text(String(localized: "10 maximal", bundle: .module))
            }
            .font(.caption)
            .foregroundStyle(PulsePalette.muted)
            .accessibilityHidden(true)
            Text(model.loadSentence)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Note", bundle: .module))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text2)
            TextField(String(localized: "Comment s'est passée la séance ?", bundle: .module),
                      text: Bindable(model).note, axis: .vertical)
                .lineLimit(2...6)
                .padding(12)
                .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous))
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 8) {
            if model.recap != nil {
                Button {
                    Task { if await model.save() { onSaved() } }
                } label: {
                    Text(model.errorMessage == nil ? String(localized: "Enregistrer", bundle: .module)
                        : String(localized: "Réessayer", bundle: .module))
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(LiveSessionIdentifiers.recapSave)
            } else if model.errorMessage != nil {
                Button {
                    Task { await model.load() }
                } label: {
                    Text(String(localized: "Réessayer", bundle: .module))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Button {
                Task { if await model.later() { onSaved() } }
            } label: {
                Text(String(localized: "Plus tard", bundle: .module))
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint(String(localized: "Enregistre la séance avec l'effort proposé", bundle: .module))
            .accessibilityIdentifier(LiveSessionIdentifiers.recapLater)
        }
        .disabled(model.isSaving)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(PulsePalette.background)
    }

    private func card(title: String, detail: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            content()
        }
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
    }
}

// MARK: - Textes

extension RecapView {
    /// « Pectoraux et triceps · lundi 2 novembre ».
    nonisolated static func subtitle(title: String, endedAt: Date, calendar: Calendar) -> String {
        let style = Date.FormatStyle(locale: Locale(identifier: "fr_FR"), calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).day().month(.wide)
        let date = endedAt.formatted(style)
        return title.isEmpty ? date : "\(title) · \(date)"
    }

    /// « Record », « Records » ; sans record, « Record » au singulier comme la maquette.
    nonisolated static func recordsTitle(_ count: Int) -> String {
        count > 1 ? String(localized: "Records", bundle: .module) : String(localized: "Record", bundle: .module)
    }

    /// « 1 série », « 9 séries ».
    nonisolated static func setsText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 série", bundle: .module) : String(localized: "\(count) séries", bundle: .module)
    }

    /// « Muscles travaillés : Pectoraux 9 séries, Bras 5 séries ».
    nonisolated static func musclesLabel(_ setsPerGroup: [(MuscleGroup, Int)]) -> String {
        let groups = setsPerGroup.map { "\($0.0.localizedName) \(setsText($0.1))" }.joined(separator: ", ")
        return String(localized: "Muscles travaillés : \(groups)", bundle: .module)
    }
}
