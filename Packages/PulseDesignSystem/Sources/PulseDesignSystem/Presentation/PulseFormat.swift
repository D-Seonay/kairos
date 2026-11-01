import Foundation

/// Formats de nombres et de durées de la maquette. Le signe moins est U+2212, les espaces sont ordinaires.
public enum PulseFormat {
    private static let minus = "\u{2212}"
    private static let dash = "\u{2014}"
    /// Au-delà, la conversion en `Int` n'a plus de sens pour un affichage.
    private static let displayLimit = 1e15

    /// « 5 h 10 », « 7 h 05 », « 8 h », « 45 min ».
    public static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 {
            return String(localized: "\(rest) min", bundle: .module)
        }
        if rest == 0 {
            return String(localized: "\(hours) h", bundle: .module)
        }
        let padded = rest < 10 ? "0\(rest)" : "\(rest)"
        return String(localized: "\(hours) h \(padded)", bundle: .module)
    }

    /// « +3 % », « −18 % », « 0 % ».
    public static func signedPercent(_ value: Double) -> String {
        guard let number = signed(value) else { return dash }
        return "\(number) %"
    }

    /// « +5 bpm », « −3 bpm », « 0 bpm ».
    public static func signedInteger(_ value: Double, unit: String) -> String {
        guard let number = signed(value) else { return dash }
        return "\(number) \(unit)"
    }

    /// « 44 ms », ou « 44 » sans unité. Une valeur non finie donne « — », sans unité.
    public static func integer(_ value: Double, unit: String?) -> String {
        guard let rounded = roundedForDisplay(value) else { return dash }
        let number = "\(rounded)"
        guard let unit else { return number }
        return "\(number) \(unit)"
    }

    /// Une valeur non finie ou hors plage ne s'affiche pas : jamais de plantage dans un formateur.
    private static func roundedForDisplay(_ value: Double) -> Int? {
        guard value.isFinite, abs(value) < displayLimit else { return nil }
        return Int(value.rounded())
    }

    private static func signed(_ value: Double) -> String? {
        guard let rounded = roundedForDisplay(value) else { return nil }
        if rounded > 0 { return "+\(rounded)" }
        if rounded < 0 { return "\(minus)\(-rounded)" }
        return "0"
    }
}
