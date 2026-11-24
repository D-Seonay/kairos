import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La vue Records (spec M7 §10) : les records de force, qui ouvrent la progression de l'exercice, puis les meilleurs temps de
/// course. Un record ignore la période ; elle ne sert qu'à marquer « nouveau » ce qui a été battu dedans.
struct RecordsSection: View {
    let records: RecordStats
    let window: StatsWindow
    /// Ouvre la fiche de l'exercice sur l'onglet Progression.
    let open: (ExerciseReference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
            StrengthRecordsCard(lines: records.strength, window: window, open: open)
            RunRecordsCard(runs: records.runs, window: window)
            Text(String(localized: "Records de tout l'historique ; « nouveau » marque ceux battus dans la période choisie.",
                        bundle: .module))
                .font(.caption)
                .foregroundStyle(PulsePalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static var newMark: String { String(localized: "nouveau", bundle: .module) }
}

// MARK: - Force

/// Une ligne par exercice : le 1RM estimé (ou les répétitions au poids du corps), la série qui l'a donné et l'écart.
private struct StrengthRecordsCard: View {
    let lines: [StrengthRecordLine]
    let window: StatsWindow
    let open: (ExerciseReference) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        StatsChartCard(title: String(localized: "Force", bundle: .module)) {
            if lines.isEmpty {
                StatsEmptyNote(reason: String(localized: """
                    aucun record sur les mouvements de base ni sur un exercice fait au moins 5 fois
                    """, bundle: .module))
            } else {
                VStack(spacing: 0) {
                    ForEach(lines) { line in
                        row(line)
                        if line.id != lines.last?.id {
                            Divider().overlay(PulsePalette.line)
                        }
                    }
                }
            }
        }
    }

    private func row(_ line: StrengthRecordLine) -> some View {
        Button {
            open(line.exercise)
        } label: {
            // Aux tailles d'accessibilité, le nom d'exercice prend toute la largeur : la valeur et le gain passent dessous.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulsePalette.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(origin(line))
                        .font(.caption)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                HStack(spacing: 12) {
                    VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                        Text(value(line))
                            .font(PulseFont.value(.headline))
                            .foregroundStyle(PulsePalette.text)
                        if let mark = mark(line) {
                            Text(mark)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulsePalette.gold)
                        }
                    }
                    if dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    RowChevron()
                }
            }
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatsText.strengthRecordSpoken(line, calendar: window.calendar, today: window.today))
        .accessibilityHint(String(localized: "Ouvre la progression de l'exercice", bundle: .module))
        .accessibilityAddTraits(.isButton)
    }

    /// « 96 kg » pour un 1RM estimé, « 14 reps » pour un record de répétitions.
    private func value(_ line: StrengthRecordLine) -> String {
        switch line.kind {
        case .repsAtWeight: String(localized: "\(Int(line.value.rounded())) reps", bundle: .module)
        default: String(localized: "\(PulseFormat.decimal(line.value, maxFractionDigits: 1)) kg", bundle: .module)
        }
    }

    /// « 85 kg × 5 · 28 oct. » ; la date seule quand la série n'est plus dans l'historique ou se fait au poids du corps.
    private func origin(_ line: StrengthRecordLine) -> String {
        var parts: [String] = []
        if let weight = line.weightKg, weight > 0, let reps = line.reps {
            parts.append(String(localized: "\(PulseFormat.decimal(weight, maxFractionDigits: 2)) kg × \(reps)", bundle: .module))
        }
        parts.append(StatsText.shortDate(line.date, calendar: window.calendar, today: window.today))
        return parts.joined(separator: " · ")
    }

    /// « +2,5 kg » (ou « +2 reps ») quand le record bat celui d'avant la période ; « nouveau » s'il est le premier.
    private func mark(_ line: StrengthRecordLine) -> String? {
        if let gain = line.gain, gain > 0 {
            return switch line.kind {
            case .repsAtWeight: String(localized: "+\(Int(gain.rounded())) reps", bundle: .module)
            default: String(localized: "+\(PulseFormat.decimal(gain, maxFractionDigits: 1)) kg", bundle: .module)
            }
        }
        return line.isNew ? RecordsSection.newMark : nil
    }
}

// MARK: - Course

/// Les meilleurs temps sur 5 km, 10 km et semi-marathon, ramenés à l'allure moyenne de la sortie (spec M7 §10).
private struct RunRecordsCard: View {
    let runs: [RunBest]
    let window: StatsWindow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        StatsChartCard(title: String(localized: "Course", bundle: .module)) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(runs) { run in
                    row(run)
                }
            }
        }
    }

    private func row(_ run: RunBest) -> some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.title(run.distance))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = detail(run) {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !isLarge { Spacer(minLength: 8) }
            VStack(alignment: isLarge ? .leading : .trailing, spacing: 2) {
                if let seconds = run.seconds {
                    Text(StatsText.raceTime(seconds: seconds))
                        .font(PulseFont.value(.headline))
                        .foregroundStyle(PulsePalette.text)
                    if run.isNew {
                        Text(RecordsSection.newMark)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulsePalette.gold)
                    }
                } else {
                    Text(String(localized: "Pas encore couru", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatsText.runRecordSpoken(run, calendar: window.calendar, today: window.today))
    }

    /// « allure moyenne de la sortie du 14 sept. ».
    private func detail(_ run: RunBest) -> String? {
        guard run.seconds != nil, let date = run.date else { return nil }
        let day = StatsText.shortDate(date, calendar: window.calendar, today: window.today)
        return String(localized: "allure moyenne de la sortie du \(day)", bundle: .module)
    }

    static func title(_ distance: RunDistance) -> String {
        switch distance {
        case .fiveK: String(localized: "5 km", bundle: .module)
        case .tenK: String(localized: "10 km", bundle: .module)
        case .half: String(localized: "Semi-marathon", bundle: .module)
        }
    }
}

#if DEBUG
#Preview("Records, 30 jours") {
    StatsSectionPreview(period: .month) { snapshot, window in
        RecordsSection(records: snapshot.records, window: window) { _ in }
    }
}

#Preview("Records, sans historique") {
    StatsSectionPreview(withHistory: false) { snapshot, window in
        RecordsSection(records: snapshot.records, window: window) { _ in }
    }
}

#Preview("Records, accessibilité 3") {
    StatsSectionPreview(period: .month) { snapshot, window in
        RecordsSection(records: snapshot.records, window: window) { _ in }
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
