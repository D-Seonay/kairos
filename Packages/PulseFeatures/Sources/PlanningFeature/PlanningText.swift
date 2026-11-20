import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les textes de l'onglet Planning, tirés de la semaine datée (spec M6 §7).
enum PlanningText {
    /// « 11 240 kg », sans décimale.
    static func tonnage(_ kilograms: Double) -> String {
        "\(kilograms.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "fr_FR")))) kg"
    }

    /// « 8,2 km ».
    static func distance(meters: Double) -> String {
        let km = (meters / 1000).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "fr_FR")))
        return String(localized: "\(km) km", bundle: .module)
    }

    /// « 5:29 /km » ; `nil` sans distance ou sans durée.
    static func pace(minutes: Double?, meters: Double?) -> String? {
        guard let minutes, let meters, minutes > 0, meters > 0 else { return nil }
        let secondsPerKm = Int((minutes * 60 / (meters / 1000)).rounded())
        return String(format: "%d:%02d /km", secondsPerKm / 60, secondsPerKm % 60)
    }

    /// Ce qu'une séance faite a donné : tonnage d'une séance de musculation, distance ou durée d'une course ou d'un vélo.
    static func result(of session: WorkoutSession) -> String {
        switch session.kind {
        case .strength:
            if session.tonnageKg > 0 { return tonnage(session.tonnageKg) }
            let sets = session.sets.filter { $0.setType != .warmup }.count
            return String(localized: "\(sets) séries", bundle: .module)
        case .run, .ride:
            if let meters = session.distanceMeters, meters > 0 { return distance(meters: meters) }
            return PulseFormat.duration(minutes: Int((session.durationMinutes ?? 0).rounded()))
        }
    }

    /// « Sortie facile · 45 min », « Fractionné · 8 km », « Course ».
    static func run(_ day: RoutineDay) -> String {
        var parts = [day.runType?.localizedName ?? String(localized: "Course", bundle: .module)]
        if let minutes = day.runTargetMinutes {
            parts.append(String(localized: "\(minutes) min", bundle: .module))
        } else if let km = day.runTargetKm {
            let distance = km.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "fr_FR")))
            parts.append(String(localized: "\(distance) km", bundle: .module))
        }
        return parts.joined(separator: " · ")
    }

    /// L'icône d'une discipline.
    static func icon(of kind: SessionKind) -> String {
        switch kind {
        case .strength: "dumbbell.fill"
        case .run: "figure.run"
        case .ride: "figure.outdoor.cycle"
        }
    }

    static func icon(of kind: RoutineDayKind) -> String {
        switch kind {
        case .strength: "dumbbell.fill"
        case .run: "figure.run"
        }
    }
}
