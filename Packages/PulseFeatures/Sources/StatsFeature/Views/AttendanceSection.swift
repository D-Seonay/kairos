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
        var spoken: [String] = []
        if let week = attendance.streak.currentWeek {
            details.append(String(localized: "cette semaine \(week.count) / \(week.target)", bundle: .module))
            spoken.append(String(localized: "cette semaine \(PulseSpoken.outOf(week.count, week.target))", bundle: .module))
        }
        return StatsTileContent(title: String(localized: "Série en cours", bundle: .module),
                                value: attendance.sessionsTotal > 0 ? Self.weeksText(attendance.streak.streak) : nil,
                                details: details, emptyReason: Self.noSessionYet, spokenDetails: spoken)
    }

    /// « 6 semaines, du 7 sept. au 18 oct. » : du lundi de la première semaine au dimanche de la dernière, sans dépasser
    /// aujourd'hui quand la série finit par la semaine en cours.
    private var bestTile: StatsTileContent {
        let calendar = window.calendar
        var details: [String] = []
        var spoken: [String] = []
        if let best = attendance.best {
            let sunday = calendar.date(byAdding: .day, value: 6, to: best.lastWeek) ?? best.lastWeek
            let last = min(sunday, window.today)
            let start = StatsText.shortDate(best.firstWeek, calendar: calendar, today: window.today)
            let end = StatsText.shortDate(last, calendar: calendar, today: window.today)
            details.append(String(localized: "du \(start) au \(end)", bundle: .module))
            let spokenStart = StatsText.spokenDate(best.firstWeek, calendar: calendar, today: window.today)
            let spokenEnd = StatsText.spokenDate(last, calendar: calendar, today: window.today)
            spoken.append(String(localized: "du \(spokenStart) au \(spokenEnd)", bundle: .module))
        }
        let target = attendance.streak.currentWeek?.target ?? 1
        let reason = target == 1
            ? String(localized: "aucune semaine n'a encore atteint l'objectif de 1 séance", bundle: .module)
            : String(localized: "aucune semaine n'a encore atteint l'objectif de \(target) séances", bundle: .module)
        return StatsTileContent(title: String(localized: "Meilleure série", bundle: .module),
                                value: attendance.best.map { Self.weeksText($0.weeks) }, details: details,
                                emptyReason: reason,
                                emptyTitle: String(localized: "Pas encore de semaine réussie", bundle: .module),
                                spokenDetails: spoken)
    }

    private var sessionsTile: StatsTileContent {
        var details = [String(localized: "sur \(window.period.title)", bundle: .module)]
        var spoken = details
        if let first = attendance.firstSession {
            let date = StatsText.shortDate(first, calendar: window.calendar, today: window.today)
            details.append(String(localized: "\(attendance.sessionsTotal) depuis le \(date)", bundle: .module))
            let spokenDay = StatsText.spokenDate(first, calendar: window.calendar, today: window.today)
            spoken.append(String(localized: "\(attendance.sessionsTotal) depuis le \(spokenDay)", bundle: .module))
        }
        return StatsTileContent(
            title: String(localized: "Séances", bundle: .module),
            value: attendance.sessionsInPeriod > 0 ? "\(attendance.sessionsInPeriod)" : nil, details: details,
            emptyReason: attendance.sessionsTotal == 0
                ? Self.noSessionYet : String(localized: "aucune séance validée sur la période", bundle: .module),
            spokenDetails: spoken)
    }

    private var durationTile: StatsTileContent {
        StatsTileContent(title: String(localized: "Durée moyenne", bundle: .module),
                         value: attendance.averageMinutes.map { StatsText.duration(minutes: $0) },
                         emptyReason: String(localized: "aucune séance chronométrée sur la période", bundle: .module),
                         spokenValue: attendance.averageMinutes.map { StatsText.durationSpoken(minutes: $0) })
    }

    private var hourTile: StatsTileContent {
        StatsTileContent(title: String(localized: "Heure habituelle", bundle: .module),
                         value: attendance.usualHour.map { String(localized: "\($0) h", bundle: .module) },
                         details: [String(localized: "début de séance le plus fréquent", bundle: .module)],
                         emptyReason: String(localized: "aucune séance validée sur la période", bundle: .module),
                         spokenValue: attendance.usualHour.map { PulseSpoken.clock(hour: $0, minute: 0) })
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
/// semaine par semaine, avec les jours entraînés en valeur.
private struct AttendanceMatrixCard: View {
    let weeks: [[AttendanceDay]]
    let calendar: Calendar
    @ScaledMetric(relativeTo: .caption) private var swatch: CGFloat = 10

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
        .accessibilityLabel(StatsText.attendanceWeekLabel(week: week, isCurrent: isCurrent, calendar: calendar))
        .accessibilityValue(StatsText.attendanceDays(week: week, calendar: calendar))
    }

    /// « Lundi en haut · Moins ○ ● ● ● ● Plus » : le sens de lecture et l'échelle d'encre ; sur deux lignes quand elle ne tient
    /// pas.
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                reading
                Spacer(minLength: 8)
                scale
            }
            VStack(alignment: .leading, spacing: 6) {
                reading
                HStack(spacing: 6) { scale }
            }
        }
        .font(.caption)
        .foregroundStyle(PulsePalette.muted)
        .accessibilityHidden(true)
    }

    private var reading: some View {
        Text(String(localized: "Lundi en haut", bundle: .module))
    }

    @ViewBuilder
    private var scale: some View {
        Text(String(localized: "Moins", bundle: .module))
        ForEach(0..<StatsInk.attendanceOpacities.count, id: \.self) { level in
            AttendanceDot(level: level).frame(width: swatch)
        }
        Text(String(localized: "Plus", bundle: .module))
    }
}

/// Une pastille : le papier teinté à 0, l'encre de plus en plus pleine de 1 à 4 ; un jour à venir (`nil`) n'est pas dessiné.
private struct AttendanceDot: View {
    let level: Int?

    private static let inks = StatsInk.attendanceOpacities.map { PulsePalette.ink.opacity($0) }

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

#Preview("Assiduité, accessibilité 3") {
    StatsSectionPreview(period: .month) { snapshot, window in
        AttendanceSection(attendance: snapshot.attendance, window: window)
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
