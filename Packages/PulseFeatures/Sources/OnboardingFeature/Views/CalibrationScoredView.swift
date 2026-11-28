import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// Le premier score : pastille « N nuits analysées », jauge, catégorie, ligne de base, interrupteur de notification, puis l'import
/// facultatif de l'historique Hevy.
struct ScoredView: View {
    @Bindable var model: OnboardingModel
    let recovery: DailyRecovery
    let baseline: BaselineSummary
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var importsHevy = false

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            scoreHeader
            baselineSection
            notificationCard
            if let train = model.environment.train { hevyImport(train) }
        } footer: {
            OnboardingButton(
                title: String(localized: "Voir ma séance du jour", bundle: .module),
                identifier: OnboardingIdentifiers.calibrationFinish, style: PrimaryButtonStyle()
            ) { await model.finish() }
        }
        // Le score prend la place de la lecture : le focus VoiceOver serait resté sur un élément disparu.
        .pulseAnnounceOnce(
            OnboardingCopy.scoreReadyAnnouncement(recovery: recovery), id: recovery.id, announcesOnAppear: true)
    }

    // MARK: - Score

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            if baseline.nightsAnalyzed > 0 { nightsPill }
            // Le titre, la jauge, la catégorie et la pastille d'état disent une seule valeur : un seul élément, porté par la jauge.
            Text(String(localized: "Ta récupération ce matin", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .padding(.top, 10)
                .accessibilityHidden(true)
            RecoveryGauge(
                score: recovery.score, category: recovery.category, style: .large, cardColor: PulsePalette.background,
                accessibilityLabel: OnboardingCopy.scoreAccessibility(recovery: recovery))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier(OnboardingIdentifiers.calibrationScore)
            Text(recovery.category.localizedName)
                .font(.system(.body, weight: .bold))
                .foregroundStyle(recovery.category.tone.color(onOpal: false))
                .accessibilityHidden(true)
            if let marker = OnboardingCopy.marker(for: recovery) {
                Text(marker)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PulsePalette.text2)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 24)
                    .background(PulsePalette.surface2, in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private var nightsPill: some View {
        let tone = PulsePalette.ok
        return Label(String(localized: "\(baseline.nightsAnalyzed) nuits analysées", bundle: .module), systemImage: "checkmark")
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(PulsePalette.okSoft, in: Capsule())
    }

    // MARK: - Ligne de base

    @ViewBuilder
    private var baselineSection: some View {
        let rows = BaselineRow.rows(from: baseline, recovery: recovery)
        VStack(alignment: .leading, spacing: 12) {
            if !rows.isEmpty {
                ObsidianCard {
                    VStack(alignment: .leading, spacing: 0) {
                        OnboardingSectionTitle(String(localized: "Ta ligne de base", bundle: .module))
                            .padding(.bottom, 6)
                        ForEach(rows.indices, id: \.self) { index in
                            baselineRow(rows[index])
                        }
                    }
                }
            }
            if let note = note(rows: rows) {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.muted)
            }
        }
    }

    /// Sans ligne : une estimation. VFC en attente de sa ligne de base : pas de phrase sur la comparaison aux 14 dernières nuits.
    private func note(rows: [BaselineRow]) -> String? {
        if rows.isEmpty { return Self.estimateNote }
        return rows.contains(where: \.isPending) ? nil : Self.baselineNote
    }

    /// Titre, valeur et écart sur une ligne ; sous le titre, aux tailles d'accessibilité, où la valeur en attente est longue.
    private func baselineRow(_ row: BaselineRow) -> some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
        return layout {
            Text(row.title)
                .foregroundStyle(PulsePalette.text2)
            if !isLarge { Spacer(minLength: 8) }
            baselineValue(row, isLarge: isLarge)
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func baselineValue(_ row: BaselineRow, isLarge: Bool) -> some View {
        HStack(spacing: 8) {
            Text(row.value)
                .font(row.isPending ? .subheadline : .body.weight(.bold).monospacedDigit())
                .multilineTextAlignment(isLarge ? .leading : .trailing)
                .foregroundStyle(row.isPending ? PulsePalette.text2 : PulsePalette.text)
            if let deviation = row.deviation {
                Text(deviation)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(PulsePalette.muted)
            }
        }
    }

    private static var baselineNote: String {
        String(
            localized: """
                Pas de période d'apprentissage : Pulse compare chaque nuit à tes 14 dernières, et la ligne de \
                base se précise au fil des semaines.
                """,
            bundle: .module)
    }

    private static var estimateNote: String {
        String(
            localized: """
                Ce score est une estimation. Pulse construira ta ligne de base au fil de tes nuits, dès \
                qu'Apple Santé aura des données à lire.
                """,
            bundle: .module)
    }

    // MARK: - Notification

    private var notificationCard: some View {
        ObsidianCard {
            Toggle(isOn: $model.notifyWhenScoreReady) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Me prévenir quand mon score est prêt", bundle: .module))
                        .font(.subheadline.weight(.bold))
                    Text(String(localized: "Une notification le matin, dès que ta nuit est lue.", bundle: .module))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            .tint(Color(PulsePalette.accent(for: theme).accent))
        }
    }
}

// MARK: - Import Hevy

extension ScoredView {
    /// « Tu viens d'une autre app ? » : le même parcours d'import que l'onglet Séance, dans une feuille. Facultatif : rien ne
    /// change pour qui ne l'ouvre pas.
    fileprivate func hevyImport(_ train: TrainEnvironment) -> some View {
        Button { importsHevy = true } label: { HevyImportOfferLabel() }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(OnboardingIdentifiers.hevyImport)
            .sheet(isPresented: $importsHevy) {
                NavigationStack {
                    HevyImportFlow(model: HevyImportModel(environment: train), onFinish: { importsHevy = false })
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "Fermer", bundle: .module)) { importsHevy = false }
                            }
                        }
                }
            }
    }
}
