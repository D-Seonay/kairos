import PhotosFeature
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import StoreKit
import SupplementsFeature
import SwiftUI
import TrainFeature

/// Le récap de fin de séance (spec M4 §17, maquette `recap`) : le bilan, les records battus, les muscles travaillés, l'effort
/// global ressenti, la note, puis « Enregistrer », « Enregistrer sans noter » (l'effort proposé) et « Revenir à la séance ». Il
/// n'a pas de bouton de fermeture : on en sort en enregistrant, ou en revenant à la séance tant que rien n'est écrit. `onSaved`
/// est appelé une fois la séance écrite ; `onResume`, s'il est donné, rouvre la séance.
public struct RecapView: View {
    private let model: RecapModel
    private let calendar: Calendar
    private let onSaved: () -> Void
    private let onResume: (() -> Void)?
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.requestReview) private var requestReview

    public init(model: RecapModel, calendar: Calendar, onSaved: @escaping () -> Void, onResume: (() -> Void)? = nil) {
        self.model = model
        self.calendar = calendar
        self.onSaved = onSaved
        self.onResume = onResume
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let recap = model.recap {
                    header(recap)
                    stats(recap)
                    if !recap.beatenRecords.isEmpty { records(recap.beatenRecords) }
                    if !recap.setsPerGroup.isEmpty { muscles(recap) }
                    if !recap.plateaus.isEmpty { plateaus(recap.plateaus) }
                    if let supplements = model.supplements, !supplements.overview.workoutItems.isEmpty {
                        card(title: String(localized: "Compléments de la séance", bundle: .module),
                             detail: Self.supplementsDetail(supplements.overview)) {
                            SupplementsWorkoutChecklist(model: supplements)
                        }
                    }
                    effort()
                    noteField
                    if let photos = model.photos { SessionPhotosSection(model: photos) }
                    if model.healthAccess == .denied { healthDeniedNote }
                } else if model.errorMessage == nil {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Préparation du récap", bundle: .module))
                        .padding(.top, 80)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .pulseAnnounceError(model.errorMessage)
        .pulseAnnounceOnce(Self.recordsAnnouncement(model.recap?.beatenRecords ?? []), id: model.recap?.startedAt,
                           announcesOnAppear: true)
        .pulseScreenBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .sheet(isPresented: isExplainingHealth) {
            HealthWriteExplanation {
                Task { if await model.continueAfterHealthExplanation() { didSave() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isExplainingHealth: Binding<Bool> {
        Binding(get: { model.isExplainingHealth }, set: { if !$0 { model.cancelHealthExplanation() } })
    }

    /// Le refus d'écrire dans Apple Santé, dit sans bloquer.
    private var healthDeniedNote: some View {
        Label {
            Text(String(localized: """
                Apple Santé : écriture refusée, la séance reste dans Pulse. Tu peux l'autoriser dans Réglages › Santé › Pulse.
                """, bundle: .module))
        } icon: {
            Image(systemName: "heart.slash").accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(PulsePalette.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bilan

    private func header(_ recap: SessionRecap) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(PulsePalette.accent(for: theme).gradient(startPoint: .topLeading, endPoint: .bottomTrailing))
                .accessibilityHidden(true)
            Text(String(localized: "Séance terminée", bundle: .module))
                .font(PulseFont.title(.title2))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            Text(Self.subtitle(title: recap.title, endedAt: recap.endedAt, calendar: calendar))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .multilineTextAlignment(.center)
            ShareCardButton(content: model.shareContent(calendar: calendar), photos: model.photos?.shareCardPhotos ?? [])
                .labelStyle(.titleAndIcon)
                .buttonStyle(PillButtonStyle())
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func stats(_ recap: SessionRecap) -> some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            stat(PulseFormat.duration(minutes: recap.durationMinutes), String(localized: "Durée", bundle: .module),
                 spoken: Self.statSpoken(.duration(minutes: recap.durationMinutes)))
            stat(PulseFormat.grouped(recap.tonnageKg, maxFractionDigits: 1), String(localized: "kg soulevés", bundle: .module),
                 spoken: Self.statSpoken(.tonnage(kg: recap.tonnageKg)))
            stat("\(recap.workingSets)", String(localized: "Séries", bundle: .module),
                 spoken: Self.statSpoken(.sets(recap.workingSets)))
            stat("\(recap.beatenRecords.count)", Self.recordsTitle(recap.beatenRecords.count),
                 spoken: Self.statSpoken(.records(recap.beatenRecords.count)),
                 color: recap.beatenRecords.isEmpty ? PulsePalette.text : PulsePalette.gold)
        }
    }

    private func stat(_ value: String, _ name: String, spoken: (name: String, value: String),
                      color: Color = PulsePalette.text) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PulseFont.value(.largeTitle))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(name)
                .pulseEyebrow()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken.name)
        .accessibilityValue(spoken.value)
    }

    private func records(_ records: [BeatenRecord]) -> some View {
        card(title: Self.recordsTitle(records.count)) {
            ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                Label {
                    Text(record.text).font(.subheadline).foregroundStyle(PulsePalette.text)
                } icon: {
                    Image(systemName: "trophy.fill").foregroundStyle(PulsePalette.gold).accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(record.spokenText)
            }
        }
    }

    // MARK: Muscles

    private func muscles(_ recap: SessionRecap) -> some View {
        let largest = max(1, recap.setsPerGroup.map(\.1).max() ?? 1)
        return card(title: String(localized: "Muscles travaillés", bundle: .module), detail: String(localized: "séries", bundle: .module),
                    detailIsSpoken: false) {
            MuscleMapView(levels: MuscleIntensity.levels(weights: recap.muscleWeights),
                          label: Self.musclesLabel(recap.setsPerGroup), height: 200)
                .frame(maxWidth: .infinity)
            ForEach(Array(recap.setsPerGroup.enumerated()), id: \.offset) { _, entry in
                RecapGroupBar(group: entry.0, count: entry.1, fraction: Double(entry.1) / Double(largest))
            }
        }
    }

    // MARK: Effort et note

    private func effort() -> some View {
        card(title: String(localized: "Effort global ressenti", bundle: .module), detail: model.effortText,
                     detailIsSpoken: false) {
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
                    Task { if await model.save() { didSave() } }
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
                Task { if await model.later() { didSave() } }
            } label: {
                Text(String(localized: "Enregistrer sans noter", bundle: .module))
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint(String(localized: "Enregistre la séance avec l'effort proposé", bundle: .module))
            .accessibilityIdentifier(LiveSessionIdentifiers.recapLater)
            if let onResume {
                Button(action: onResume) {
                    Text(String(localized: "Revenir à la séance", bundle: .module))
                }
                .buttonStyle(PulseDesignSystem.LinkButtonStyle())
                .accessibilityHint(String(localized: "Rien n'est encore enregistré", bundle: .module))
                .accessibilityIdentifier(LiveSessionIdentifiers.recapResume)
            }
        }
        .disabled(model.isSaving)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(PulsePalette.background)
    }
}

// La carte commune du récap, hors du corps du type pour qu'il reste court.
extension RecapView {
    /// `detailIsSpoken` est faux quand le détail double ce que VoiceOver dit déjà ailleurs (le curseur d'effort, l'unité des barres).
    private func card(title: String, detail: String? = nil, detailIsSpoken: Bool = true,
                      @ViewBuilder content: () -> some View) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
        return VStack(alignment: .leading, spacing: 10) {
            layout {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                if let detail {
                    Text(detail)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(PulsePalette.text2)
                        .accessibilityHidden(!detailIsSpoken)
                }
            }
            .accessibilityElement(children: .combine)
            content()
        }
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
    }
}

// La sortie après l'enregistrement : la demande de note si la règle la veut, puis la fermeture. iOS décide d'afficher ou non
// la fenêtre (jamais sur TestFlight, trois fois par an au plus sur l'App Store).
extension RecapView {
    private func didSave() {
        if model.shouldRequestReview { requestReview() }
        onSaved()
    }
}

// Le plateau confirmé par la séance : un signal discret, après les muscles, avec le calcul et les pistes.
extension RecapView {
    private func plateaus(_ notices: [PlateauNotice]) -> some View {
        // Un seul exercice : son nom dans le titre. Plusieurs : chacun avec son calcul et sa variante, puis les pistes une fois.
        let single = notices.count == 1 ? notices.first : nil
        let title = single.map { String(localized: "Plateau possible : \($0.exerciseName)", bundle: .module) }
            ?? String(localized: "Plateaux possibles", bundle: .module)
        let items = notices.map { notice in
            ExercisePlateauView.Item(name: single == nil ? notice.exerciseName : nil, plateau: notice.plateau, calendar: calendar,
                                     variant: single == nil ? notice.variantName : nil)
        }
        return ExercisePlateauView(title: title, items: items, variantName: single?.variantName)
            .padding(PulseMetrics.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
    }
}

// MARK: - Textes

extension RecapView {
    /// « 1 sur 2 », les compléments de la séance déjà pris.
    static func supplementsDetail(_ overview: SupplementOverview) -> String {
        let items = overview.workoutItems
        return String(localized: "\(items.filter(\.isTaken).count) sur \(items.count)", bundle: .module)
    }

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
