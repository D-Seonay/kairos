import Foundation

/// Une ligne « une par jour civil » : score, check-in ou lecture de nuit.
protocol DayKeyedRow: AnyObject {
    var day: Date { get }
    var dayKey: String? { get set }
    var updatedAt: Date { get }
    /// Départage deux lignes écrites au même instant, de la même façon sur tous les appareils.
    var tieBreaker: String { get }
}

extension StoredDailyRecovery: DayKeyedRow {
    var tieBreaker: String { id.uuidString }
}

extension StoredCheckIn: DayKeyedRow {
    var tieBreaker: String { id.uuidString }
}

extension StoredRecoveryReading: DayKeyedRow {
    var tieBreaker: String { String(day.timeIntervalSinceReferenceDate) }
}

/// Deux appareils, ou un voyage, peuvent laisser plusieurs lignes pour un même jour civil : la plus récente fait foi.
enum DayRows {
    /// Les lignes par jour civil, la plus récente d'abord (`updatedAt`, puis `tieBreaker`).
    static func byDay<Row: DayKeyedRow>(_ rows: [Row], calendar: Calendar) -> [String: [Row]] {
        var groups: [String: [Row]] = [:]
        for row in rows {
            groups[DayKey.effective(row.dayKey, day: row.day, calendar: calendar), default: []].append(row)
        }
        for (key, group) in groups where group.count > 1 {
            groups[key] = group.sorted { ($0.updatedAt, $0.tieBreaker) > ($1.updatedAt, $1.tieBreaker) }
        }
        return groups
    }
}
