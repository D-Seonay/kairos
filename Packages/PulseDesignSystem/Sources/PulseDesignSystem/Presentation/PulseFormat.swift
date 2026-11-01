import Foundation

/// Formats de nombres et de durées de la maquette. Le signe moins est U+2212, les espaces sont ordinaires.
public enum PulseFormat {
    private static let minus = "\u{2212}"

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
        "\(signed(value)) %"
    }

    /// « +5 bpm », « −3 bpm », « 0 bpm ».
    public static func signedInteger(_ value: Double, unit: String) -> String {
        "\(signed(value)) \(unit)"
    }

    /// « 44 ms », ou « 44 » sans unité.
    public static func integer(_ value: Double, unit: String?) -> String {
        let number = "\(Int(value.rounded()))"
        guard let unit else { return number }
        return "\(number) \(unit)"
    }

    private static func signed(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)" }
        if rounded < 0 { return "\(minus)\(-rounded)" }
        return "0"
    }
}
