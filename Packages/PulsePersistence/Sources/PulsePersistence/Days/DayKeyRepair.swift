import Foundation
import SwiftData

/// Remplit la clé de jour civil des lignes qui n'en ont pas et retire les doublons d'un même jour, le plus récent gagnant.
/// Les scores et check-ins en trop sont marqués supprimés (la marque part dans iCloud : les autres appareils, qui appliquent la
/// même règle, gardent la même ligne) ; les lectures locales en trop sont supprimées pour de bon. Sans drapeau « déjà fait » :
/// lancé à chaque ouverture du magasin, il ne fait rien quand tout est en ordre, et rattrape les lignes arrivées d'iCloud depuis
/// un appareil resté sur une version plus ancienne.
enum DayKeyRepair {
    /// Rend vrai si quelque chose a changé (et a été enregistré).
    @discardableResult
    static func run(in context: ModelContext, calendar: Calendar, now: Date) throws -> Bool {
        let recoveries = try context.fetch(FetchDescriptor<StoredDailyRecovery>(predicate: #Predicate { $0.deletedAt == nil }))
        for duplicate in repair(recoveries, calendar: calendar) {
            duplicate.deletedAt = now
            duplicate.updatedAt = now
        }
        let checkIns = try context.fetch(FetchDescriptor<StoredCheckIn>(predicate: #Predicate { $0.deletedAt == nil }))
        for duplicate in repair(checkIns, calendar: calendar) {
            duplicate.deletedAt = now
            duplicate.updatedAt = now
        }
        let readings = try context.fetch(FetchDescriptor<StoredRecoveryReading>())
        for duplicate in repair(readings, calendar: calendar) {
            context.delete(duplicate)
        }
        guard context.hasChanges else { return false }
        try context.save()
        return true
    }

    /// Donne leur clé aux lignes qui n'en ont pas et rend les doublons à retirer.
    private static func repair<Row: DayKeyedRow>(_ rows: [Row], calendar: Calendar) -> [Row] {
        var duplicates: [Row] = []
        for (key, group) in DayRows.byDay(rows, calendar: calendar) {
            for row in group where row.dayKey == nil {
                row.dayKey = key
            }
            duplicates += group.dropFirst()
        }
        return duplicates
    }
}
