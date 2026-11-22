import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La vue Muscles (spec M7 §8) : la carte de chaleur face et dos et les huit muscles les plus travaillés, les groupes peu
/// sollicités en couleur signal, puis l'équilibre pousser / tirer et haut / bas.
struct MusclesSection: View {
    let muscles: MuscleStats
    let window: StatsWindow

    var body: some View {
        VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
            MuscleMapCard(muscles: muscles, window: window)
            // Sous 30 jours ou sans séance chaque semaine, aucune ligne : ni groupe délaissé, ni faux « tout va bien ».
            if !muscles.neglected.isEmpty {
                NeglectedCard(groups: muscles.neglected, window: window)
            }
            BalanceCard(muscles: muscles)
        }
    }

    static func setsText(_ sets: Double) -> String { StatsText.setsText(sets) }

    static func inlineName(_ muscle: Muscle) -> String { StatsText.inlineName(muscle) }
}

// MARK: - Carte et plus travaillés

/// La carte de chaleur face et dos, puis les huit muscles au plus haut total de séries pondérées.
private struct MuscleMapCard: View {
    let muscles: MuscleStats
    let window: StatsWindow
    @ScaledMetric(relativeTo: .body) private var mapHeight: CGFloat = 200

    var body: some View {
        StatsChartCard(title: String(localized: "Séries par muscle", bundle: .module), trailing: sessionsText) {
            if muscles.top.isEmpty {
                StatsEmptyNote(reason: emptyReason)
            } else {
                MuscleMapView(levels: MuscleIntensity.levels(weights: muscles.weights),
                              label: StatsText.mapSummary(top: muscles.top, period: window.period), height: mapHeight)
                    .frame(maxWidth: .infinity)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    ForEach(muscles.top) { load in
                        GridRow {
                            Text(load.muscle.localizedName)
                                .font(.subheadline)
                                .foregroundStyle(PulsePalette.text)
                            Text(MusclesSection.setsText(load.sets))
                                .font(PulseFont.value(.subheadline))
                                .foregroundStyle(PulsePalette.text2)
                                .gridColumnAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var sessionsText: String? {
        switch muscles.strengthSessions {
        case 0: nil
        case 1: String(localized: "1 séance", bundle: .module)
        case let count: String(localized: "\(count) séances", bundle: .module)
        }
    }

    private var emptyReason: String {
        muscles.strengthSessions == 0
            ? String(localized: "aucune séance de musculation terminée sur la période", bundle: .module)
            : String(localized: "aucune série de travail d'un exercice connu sur la période", bundle: .module)
    }
}

// MARK: - Peu sollicités

/// Une phrase factuelle par groupe délaissé, en couleur signal ; pas de conseil de programme (spec M7 §8).
private struct NeglectedCard: View {
    let groups: [NeglectedGroup]
    let window: StatsWindow

    var body: some View {
        StatsChartCard(title: String(localized: "Peu sollicités", bundle: .module)) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(groups) { group in
                    Text(Self.sentence(group, period: window.period))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulsePalette.signal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// « Tronc peu sollicité : 14 séries en 30 jours — abdominaux 8, obliques 6. » ; « … : aucune série en 30 jours. »
    static func sentence(_ group: NeglectedGroup, period: StatsPeriod) -> String {
        let head = headline(group.group)
        let days = period.title
        guard !group.muscles.isEmpty else {
            return String(localized: "\(head) : aucune série en \(days).", bundle: .module)
        }
        let total = MusclesSection.setsText(group.muscles.reduce(0) { $0 + $1.sets })
        let detail = group.muscles
            .map { "\(MusclesSection.inlineName($0.muscle)) \(PulseFormat.decimal($0.sets, maxFractionDigits: 1))" }
            .joined(separator: ", ")
        return String(localized: "\(head) : \(total) en \(days) — \(detail).", bundle: .module)
    }

    /// Le groupe et son adjectif accordé.
    private static func headline(_ group: MuscleGroup) -> String {
        switch group {
        case .chest: String(localized: "Pectoraux peu sollicités", bundle: .module)
        case .back: String(localized: "Dos peu sollicité", bundle: .module)
        case .shoulders: String(localized: "Épaules peu sollicitées", bundle: .module)
        case .arms: String(localized: "Bras peu sollicités", bundle: .module)
        case .legs: String(localized: "Jambes peu sollicitées", bundle: .module)
        case .core: String(localized: "Tronc peu sollicité", bundle: .module)
        }
    }
}

// MARK: - Équilibre

/// Pousser / tirer et haut / bas : les séries de travail de chaque côté et leur rapport, en signal hors de 0,67 – 1,5.
private struct BalanceCard: View {
    let muscles: MuscleStats

    var body: some View {
        StatsChartCard(title: String(localized: "Équilibre", bundle: .module)) {
            VStack(alignment: .leading, spacing: 14) {
                BalanceRow(title: String(localized: "Pousser / tirer", bundle: .module),
                           spokenTitle: String(localized: "Pousser et tirer", bundle: .module),
                           first: muscles.push, second: muscles.pull, isUnbalanced: muscles.isPushPullUnbalanced,
                           emptyReason: String(localized: "aucune série de poussée ni de tirage sur la période", bundle: .module),
                           firstMissing: String(localized: "aucune série de poussée", bundle: .module),
                           secondMissing: String(localized: "aucune série de tirage", bundle: .module))
                BalanceRow(title: String(localized: "Haut / bas", bundle: .module),
                           spokenTitle: String(localized: "Haut et bas du corps", bundle: .module),
                           first: muscles.upper, second: muscles.lower, isUnbalanced: muscles.isUpperLowerUnbalanced,
                           emptyReason: String(localized: "aucune série du haut ni du bas du corps sur la période",
                                               bundle: .module),
                           firstMissing: String(localized: "aucune série du haut du corps", bundle: .module),
                           secondMissing: String(localized: "aucune série du bas du corps", bundle: .module))
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(PulsePalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// « Séries de travail, tronc exclu ; équilibré de 0,67 à 1,5. »
    private var footnote: String {
        let low = PulseFormat.decimal(MuscleStats.balanceRange.lowerBound, maxFractionDigits: 2)
        let high = PulseFormat.decimal(MuscleStats.balanceRange.upperBound, maxFractionDigits: 2)
        return String(localized: "Séries de travail, tronc exclu ; équilibré de \(low) à \(high).", bundle: .module)
    }
}

/// Une ligne d'équilibre : « 18 / 9 séries » et « ratio 2 » ; sans série d'aucun côté, « Pas assez de données ». Hors de la
/// plage équilibrée, le mot « déséquilibré » s'écrit, avec une icône : la couleur ne porte jamais seule l'information.
private struct BalanceRow: View {
    let title: String
    let spokenTitle: String
    let first: Int
    let second: Int
    let isUnbalanced: Bool
    let emptyReason: String
    let firstMissing: String
    let secondMissing: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).pulseEyebrow()
            if first == 0, second == 0 {
                StatsEmptyNote(reason: emptyReason)
            } else {
                values
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatsText.balanceSpoken(title: spokenTitle, first: first, second: second, isUnbalanced: isUnbalanced,
                                                    emptyReason: emptyReason, firstMissing: firstMissing,
                                                    secondMissing: secondMissing))
    }

    private var values: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(String(localized: "\(first) / \(second) séries", bundle: .module))
                .font(PulseFont.value(.title3))
                .foregroundStyle(PulsePalette.text)
                .fixedSize(horizontal: false, vertical: true)
            if !isLarge { Spacer(minLength: 8) }
            VStack(alignment: isLarge ? .leading : .trailing, spacing: 2) {
                Text(StatsText.balanceRatioText(first: first, second: second, firstMissing: firstMissing,
                                                secondMissing: secondMissing))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnbalanced ? PulsePalette.signal : PulsePalette.text2)
                    .multilineTextAlignment(isLarge ? .leading : .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                if isUnbalanced {
                    Label(String(localized: "déséquilibré", bundle: .module), systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulsePalette.signal)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Muscles, 30 jours") {
    StatsSectionPreview(period: .month) { snapshot, window in MusclesSection(muscles: snapshot.muscles, window: window) }
}

#Preview("Muscles, 7 jours") {
    StatsSectionPreview(period: .week) { snapshot, window in MusclesSection(muscles: snapshot.muscles, window: window) }
}

#Preview("Muscles, sans historique") {
    StatsSectionPreview(withHistory: false) { snapshot, window in MusclesSection(muscles: snapshot.muscles, window: window) }
}

#Preview("Muscles, accessibilité 3") {
    StatsSectionPreview(period: .month) { snapshot, window in MusclesSection(muscles: snapshot.muscles, window: window) }
        .dynamicTypeSize(.accessibility3)
}
#endif
