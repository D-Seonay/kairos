import Foundation
import PulseDesignSystem
import PulseServices
import SwiftUI

/// La vue Assiduité (spec M7 §9) : la matrice des 16 dernières semaines, puis la série en cours, la meilleure série, les séances,
/// la durée moyenne, l'heure habituelle et la régularité.
struct AttendanceSection: View {
    let attendance: AttendanceStats
    let window: StatsWindow

    var body: some View {
        VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
            AttendanceMatrixCard(weeks: attendance.weeks, calendar: window.calendar)
            StatsTileGrid(tiles: [streakTile, bestTile, sessionsTile, durationTile, hourTile, regularityTile])
        }
    }

    private static var noSessionYet: String { String(localized: "aucune séance validée pour l'instant", bundle: .module) }

    /// « 1 semaine », « 3 semaines » (et « 0 semaine »).
    static func weeksText(_ weeks: Int) -> String {
        weeks < 2
            ? String(localized: "\(weeks) semaine", bundle: .module)
            : String(localized: "\(weeks) semaines", bundle: .module)
    }

    private var streakTile: StatsTileContent {
        var details: [String] = []
        if let week = attendance.streak.currentWeek {
            details.append(String(localized: "cette semaine \(week.count) / \(week.target)", bundle: .module))
        }
        return StatsTileContent(title: String(localized: "Série en cours", bundle: .module),
                                value: attendance.sessionsTotal > 0 ? Self.weeksText(attendance.streak.streak) : nil,
                                details: details, emptyReason: Self.noSessionYet)
    }

    /// « 6 semaines, du 7 sept. au 18 oct. » : du lundi de la première semaine au dimanche de la dernière, sans dépasser
    /// aujourd'hui quand la série finit par la semaine en cours.
    private var bestTile: StatsTileContent {
        let calendar = window.calendar
        var details: [String] = []
        if let best = attendance.best {
            let sunday = calendar.date(byAdding: .day, value: 6, to: best.lastWeek) ?? best.lastWeek
            let start = StatsText.shortDate(best.firstWeek, calendar: calendar, today: window.today)
            let end = StatsText.shortDate(min(sunday, window.today), calendar: calendar, today: window.today)
            details.append(String(localized: "du \(start) au \(end)", bundle: .module))
        }
        let target = attendance.streak.currentWeek?.target ?? 1
        let reason = target == 1
            ? String(localized: "aucune semaine n'a encore atteint l'objectif de 1 séance", bundle: .module)
            : String(localized: "aucune semaine n'a encore atteint l'objectif de \(target) séances", bundle: .module)
        return StatsTileContent(title: String(localized: "Meilleure série", bundle: .module),
                                value: attendance.best.map { Self.weeksText($0.weeks) }, details: details,
                                emptyReason: reason,
                                emptyTitle: String(localized: "Pas encore de semaine réussie", bundle: .module))
    }

    private var sessionsTile: StatsTileContent {
        var details = [String(localized: "sur \(window.period.title)", bundle: .module)]
        if let first = attendance.firstSession {
            let date = StatsText.shortDate(first, calendar: window.calendar, today: window.today)
            details.append(String(localized: "\(attendance.sessionsTotal) depuis le \(date)", bundle: .module))
        }
        return StatsTileContent(
            title: String(localized: "Séances", bundle: .module),
            value: attendance.sessionsInPeriod > 0 ? "\(attendance.sessionsInPeriod)" : nil, details: details,
            emptyReason: attendance.sessionsTotal == 0
                ? Self.noSessionYet : String(localized: "aucune séance validée sur la période", bundle: .module))
    }

    private var durationTile: StatsTileContent {
        StatsTileContent(title: String(localized: "Durée moyenne", bundle: .module),
                         value: attendance.averageMinutes.map { StatsText.duration(minutes: $0) },
                         emptyReason: String(localized: "aucune séance chronométrée sur la période", bundle: .module))
    }

    private var hourTile: StatsTileContent {
        StatsTileContent(title: String(localized: "Heure habituelle", bundle: .module),
                         value: attendance.usualHour.map { String(localized: "\($0) h", bundle: .module) },
                         details: [String(localized: "début de séance le plus fréquent", bundle: .module)],
                         emptyReason: String(localized: "aucune séance validée sur la période", bundle: .module))
    }

    private var regularityTile: StatsTileContent {
        var details = [String(localized: "semaines réussies sur la période", bundle: .module)]
        if let target = attendance.streak.currentWeek?.target {
            details.append(target == 1
                ? String(localized: "objectif 1 séance par semaine", bundle: .module)
                : String(localized: "objectif \(target) séances par semaine", bundle: .module))
        }
        return StatsTileContent(title: String(localized: "Régularité", bundle: .module),
                                value: attendance.regularity.map { PulseFormat.integer($0 * 100, unit: "%") },
                                details: details,
                                emptyReason: String(localized: "aucune semaine à juger sur la période", bundle: .module))
    }
}

// MARK: - Matrice

/// Seize colonnes de sept pastilles (lundi en haut, la semaine en cours à droite), à cinq niveaux d'encre. VoiceOver la lit
/// semaine par semaine.
private struct AttendanceMatrixCard: View {
    let weeks: [[AttendanceDay]]
    let calendar: Calendar

    var body: some View {
        StatsChartCard(title: String(localized: "16 dernières semaines", bundle: .module)) {
            if weeks.joined().allSatisfy({ $0.level == 0 }) {
                StatsEmptyNote(reason: String(localized: "aucune séance validée sur les 16 dernières semaines", bundle: .module))
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(weeks.indices, id: \.self) { index in
                        column(weeks[index], isCurrent: index == weeks.count - 1)
                    }
                }
                legend
            }
        }
    }

    private func column(_ week: [AttendanceDay], isCurrent: Bool) -> some View {
        VStack(spacing: 4) {
            ForEach(week) { day in
                AttendanceDot(level: day.isFuture ? nil : day.level)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(week, isCurrent: isCurrent))
    }

    /// « Semaine du 3 novembre : 4 jours d'entraînement » ; la semaine en cours le dit.
    private func label(_ week: [AttendanceDay], isCurrent: Bool) -> String {
        let monday = week.first.map { StatsText.dayMonth($0.date, calendar: calendar) } ?? ""
        let title = isCurrent
            ? String(localized: "Semaine en cours, du \(monday)", bundle: .module)
            : String(localized: "Semaine du \(monday)", bundle: .module)
        let days = week.filter { $0.level > 0 }.count
        let count = switch days {
        case 0: String(localized: "aucun jour d'entraînement", bundle: .module)
        case 1: String(localized: "1 jour d'entraînement", bundle: .module)
        default: String(localized: "\(days) jours d'entraînement", bundle: .module)
        }
        return String(localized: "\(title) : \(count)", bundle: .module)
    }

    /// « Lundi en haut · Moins ○ ● ● ● ● Plus » : le sens de lecture et l'échelle d'encre.
    private var legend: some View {
        HStack(spacing: 6) {
            Text(String(localized: "Lundi en haut", bundle: .module))
            Spacer(minLength: 8)
            Text(String(localized: "Moins", bundle: .module))
            ForEach(0..<5, id: \.self) { level in
                AttendanceDot(level: level).frame(width: 10)
            }
            Text(String(localized: "Plus", bundle: .module))
        }
        .font(.caption)
        .foregroundStyle(PulsePalette.muted)
        .accessibilityHidden(true)
    }
}

/// Une pastille : le papier teinté à 0, l'encre de plus en plus pleine de 1 à 4 ; un jour à venir (`nil`) n'est pas dessiné.
private struct AttendanceDot: View {
    let level: Int?

    private static let inks = [StatsInk.zone, PulsePalette.ink.opacity(0.25), PulsePalette.ink.opacity(0.5),
                               PulsePalette.ink.opacity(0.75), PulsePalette.ink]

    var body: some View {
        Circle()
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
    }

    private var fill: Color {
        guard let level else { return .clear }
        return Self.inks[min(max(level, 0), Self.inks.count - 1)]
    }
}

#if DEBUG
#Preview("Assiduité, 30 jours") {
    StatsSectionPreview(period: .month) { snapshot, window in
        AttendanceSection(attendance: snapshot.attendance, window: window)
    }
}

#Preview("Assiduité, 1 an") {
    StatsSectionPreview(period: .year) { snapshot, window in
        AttendanceSection(attendance: snapshot.attendance, window: window)
    }
}

#Preview("Assiduité, sans historique") {
    StatsSectionPreview(withHistory: false) { snapshot, window in
        AttendanceSection(attendance: snapshot.attendance, window: window)
    }
}
#endif
