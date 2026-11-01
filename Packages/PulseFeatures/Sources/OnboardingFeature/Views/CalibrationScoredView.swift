import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Le premier score : pastille « N nuits analysées », jauge, catégorie, ligne de base, interrupteur de notification.
struct ScoredView: View {
    @Bindable var model: OnboardingModel
    let recovery: DailyRecovery
    let baseline: BaselineSummary
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            scoreHeader
            baselineSection
            notificationCard
        } footer: {
            OnboardingButton(
                title: String(localized: "Voir ma séance du jour", bundle: .module),
                identifier: OnboardingIdentifiers.calibrationFinish, style: PrimaryButtonStyle()
            ) { await model.finish() }
        }
    }

    // MARK: - Score

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            if baseline.nightsAnalyzed > 0 { nightsPill }
            Text(String(localized: "Ta récupération ce matin", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .padding(.top, 10)
            RecoveryGauge(score: recovery.score, category: recovery.category, style: .large, cardColor: PulsePalette.background)
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier(OnboardingIdentifiers.calibrationScore)
            Text(recovery.category.localizedName)
                .font(.system(.body, weight: .bold))
                .foregroundStyle(recovery.category.tone.color(onOpal: false))
                .accessibilityIdentifier(OnboardingIdentifiers.calibrationCategory)
            if let marker = OnboardingCopy.marker(for: recovery) {
                Text(marker)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(PulsePalette.text2)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 24)
                    .background(PulsePalette.surface2, in: Capsule())
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
        let rows = BaselineRow.rows(from: baseline)
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
            Text(rows.isEmpty ? Self.estimateNote : Self.baselineNote)
                .font(.footnote)
                .foregroundStyle(PulsePalette.muted)
        }
    }

    private func baselineRow(_ row: BaselineRow) -> some View {
        HStack {
            Text(row.title)
                .foregroundStyle(PulsePalette.text2)
            Spacer(minLength: 8)
            Text(row.value)
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(PulsePalette.text)
            if let deviation = row.deviation {
                Text(deviation)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(PulsePalette.muted)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
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
