import Foundation

/// Les repères d'un super set : « A1 », « A2 », « A3 » pour les membres du premier groupe, « B1 », « B2 » pour le suivant.
/// La lettre suit l'ordre des groupes dans la séance, le chiffre la place dans le groupe ; un exercice seul n'en a pas.
public enum SupersetLabel {
    /// Le repère de chaque position de `groups` (le groupe de chaque exercice, dans l'ordre) : seuls les membres consécutifs
    /// d'un même groupe, au moins deux, en reçoivent un.
    public static func labels(for groups: [Int?]) -> [String?] {
        var labels = [String?](repeating: nil, count: groups.count)
        var block = 0
        var start = 0
        while start < groups.count {
            var end = start + 1
            while end < groups.count, groups[end] == groups[start] { end += 1 }
            if groups[start] != nil, end - start >= 2 {
                for position in start..<end { labels[position] = "\(letter(block))\(position - start + 1)" }
                block += 1
            }
            start = end
        }
        return labels
    }

    /// « A » pour le premier groupe, « B » pour le deuxième… ; après « Z », le numéro du groupe.
    public static func letter(_ block: Int) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return letters.indices.contains(block) ? String(letters[block]) : "\(block + 1)"
    }
}

extension LiveSession {
    /// « A1 », « A2 », « A3 » : le repère de l'exercice `id` dans son super set, dans l'ordre de la séance ; `nil` hors groupe.
    public func supersetLabel(of id: UUID) -> String? {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else { return nil }
        return SupersetLabel.labels(for: exercises.map(\.supersetGroup))[index]
    }
}
