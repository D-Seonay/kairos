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

    /// « 14 séries », « 1 série », « 0,5 série » : des séries pondérées, une décimale au plus.
    static func setsText(_ sets: Double) -> String {
        let rounded = (sets * 10).rounded() / 10
        let number = PulseFormat.decimal(rounded, maxFractionDigits: 1)
        return rounded < 2
            ? String(localized: "\(number) série", bundle: .module)
            : String(localized: "\(number) séries", bundle: .module)
    }

    /// « abdominaux », « deltoïdes latéraux » : le nom du muscle au milieu d'une phrase.
    static func inlineName(_ muscle: Muscle) -> String {
        let name = muscle.localizedName
        return name.prefix(1).lowercased() + name.dropFirst()
    }
}

// MARK: - Carte et plus travaillés

/// La carte de chaleur face et dos, puis les huit muscles au plus haut total de séries pondérées.
private struct MuscleMapCard: View {
    let muscles: MuscleStats
    let window: StatsWindow

    var body: some View {
        StatsChartCard(title: String(localized: "Séries par muscle", bundle: .module), trailing: sessionsText) {
            if muscles.top.isEmpty {
                StatsEmptyNote(reason: emptyReason)
            } else {
                MuscleMapView(levels: MuscleIntensity.levels(weights: muscles.weights), label: mapLabel, height: 200)
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

    /// « Muscles travaillés, 30 jours : pectoraux 14 séries, quadriceps 12 séries, grands dorsaux 11,5 séries. »
    private var mapLabel: String {
        let names = muscles.top.prefix(3)
            .map { "\(MusclesSection.inlineName($0.muscle)) \(MusclesSection.setsText($0.sets))" }
            .joined(separator: ", ")
        let period = window.period.title
        return String(localized: "Muscles travaillés, \(period) : \(names).", bundle: .module)
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
                           first: muscles.push, second: muscles.pull, isUnbalanced: muscles.isPushPullUnbalanced,
                           emptyReason: String(localized: "aucune série de poussée ni de tirage sur la période", bundle: .module),
                           firstMissing: String(localized: "aucune série de poussée", bundle: .module),
                           secondMissing: String(localized: "aucune série de tirage", bundle: .module))
                BalanceRow(title: String(localized: "Haut / bas", bundle: .module),
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

/// Une ligne d'équilibre : « 18 / 9 séries » et « ratio 2 » ; sans série d'aucun côté, « Pas assez de données ».
private struct BalanceRow: View {
    let title: String
    let first: Int
    let second: Int
    let isUnbalanced: Bool
    let emptyReason: String
    let firstMissing: String
    let secondMissing: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).pulseEyebrow()
            if first == 0, second == 0 {
                StatsEmptyNote(reason: emptyReason)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(localized: "\(first) / \(second) séries", bundle: .module))
                        .font(PulseFont.value(.title3))
                        .foregroundStyle(PulsePalette.text)
                    Spacer(minLength: 8)
                    Text(ratioText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isUnbalanced ? PulsePalette.signal : PulsePalette.text2)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var ratioText: String {
        guard second > 0 else { return secondMissing }
        guard first > 0 else { return firstMissing }
        let value = Double(first) / Double(second)
        return String(localized: "ratio \(Self.ratioText(value))", bundle: .module)
    }

    /// « 1,2 » ; deux décimales près d'une borne de `balanceRange` (« 0,66 », « 1,52 »), arrondies vers l'extérieur hors des
    /// bornes (2 / 3 donne « 0,66 », pas « 0,67 ») : l'arrondi ne contredit jamais le signal.
    static func ratioText(_ ratio: Double) -> String {
        let range = MuscleStats.balanceRange
        guard abs(ratio - range.lowerBound) <= 0.05 || abs(ratio - range.upperBound) <= 0.05 else {
            return PulseFormat.decimal(ratio, maxFractionDigits: 1)
        }
        let shown = ratio < range.lowerBound ? (ratio * 100).rounded(.down) / 100
            : ratio > range.upperBound ? (ratio * 100).rounded(.up) / 100 : ratio
        return PulseFormat.decimal(shown, maxFractionDigits: 2)
    }

    /// « Pousser / tirer : 18 séries contre 9, ratio 2, déséquilibré. »
    private var accessibilityText: String {
        guard first > 0 || second > 0 else {
            return String(localized: "\(title) : \(StatsEmptyNote.title), \(emptyReason).", bundle: .module)
        }
        let verdict = isUnbalanced
            ? String(localized: "déséquilibré", bundle: .module)
            : String(localized: "équilibré", bundle: .module)
        return String(localized: "\(title) : \(first) séries contre \(second), \(ratioText), \(verdict).", bundle: .module)
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
#endif
