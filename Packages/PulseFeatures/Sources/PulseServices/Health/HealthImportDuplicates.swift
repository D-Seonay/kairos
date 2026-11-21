import Foundation

/// Les lignes importées d'Apple Santé passent par iCloud, le cache non : deux appareils qui importent le même échantillon avant
/// de se synchroniser en font deux lignes au même identifiant Apple Santé. Une seule est gardée par identifiant.
enum HealthImportDuplicates {
    /// La ligne gardée par identifiant (la première selon `isPreferred`) et les autres, à supprimer. Une ligne sans identifiant
    /// n'est ni gardée ni en double.
    static func split<Row>(_ rows: [Row], uuid: (Row) -> String?,
                           isPreferred: (Row, Row) -> Bool) -> (kept: [String: Row], duplicates: [Row]) {
        var kept = [String: Row]()
        var duplicates = [Row]()
        for row in rows.sorted(by: isPreferred) {
            guard let key = uuid(row) else { continue }
            if kept[key] == nil { kept[key] = row } else { duplicates.append(row) }
        }
        return (kept, duplicates)
    }
}
