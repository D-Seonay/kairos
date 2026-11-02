import Foundation

/// Normalisation des textes pour la recherche et la correspondance des noms Hevy.
public enum SearchText {
    private static let french = Locale(identifier: "fr_FR")

    /// Minuscules, sans diacritiques, ponctuation et tirets remplacés par une espace, espaces réduites et rognées.
    public static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: french)
        let spaced = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }
}
