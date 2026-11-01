import Foundation

/// Écriture CSV au format RFC 4180 : virgule, guillemets doublés, champ entouré si nécessaire, vide pour nil.
public enum CSVWriter {
    public static func line(_ fields: [String?]) -> String {
        fields.map { escape($0 ?? "") }.joined(separator: ",")
    }

    public static func file(header: [String], rows: [[String?]]) -> String {
        ([line(header)] + rows.map { line($0) }).joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
