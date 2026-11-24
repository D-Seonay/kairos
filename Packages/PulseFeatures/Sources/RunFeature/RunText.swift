import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les textes de la course, affichés et parlés. À l'oral, les unités en toutes lettres via `PulseSpoken` ; à l'écran, les valeurs
/// via `PulseFormat`. Des fonctions pures, testées.
public enum RunText {
    private static let dash = "—"
    /// Rayon moyen de la Terre, en mètres, pour la distance du tracé.
    private static let earthRadius = 6_371_000.0

    // MARK: Annonces vocales

    /// Ce que la course dit à voix haute : « 3 kilomètres. 16 minutes 40. Allure 5 minutes 32 par kilomètre. », « Mi-objectif. »,
    /// « Objectif atteint. ». Passée telle quelle au service comme `spokenText`.
    @Sendable public static func spokenText(for event: RunAnnouncementEvent) -> String {
        switch event {
        case let .kilometer(kilometer, movingSeconds, splitSeconds):
            let count = kilometres(kilometer)
            let time = PulseSpoken.duration(seconds: movingSeconds)
            let pace = PulseSpoken.pace(secondsPerKilometer: splitSeconds)
            return String(localized: "\(count). \(time). Allure \(pace).", bundle: .module)
        case .halfTarget:
            return String(localized: "Mi-objectif.", bundle: .module)
        case .targetReached:
            return String(localized: "Objectif atteint.", bundle: .module)
        }
    }

    /// « 1 kilomètre », « 3 kilomètres ».
    static func kilometres(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "kilomètre", bundle: .module),
                          plural: String(localized: "kilomètres", bundle: .module))
    }

    /// Le km passé entre deux distances, pour VoiceOver (priorité basse) ; `nil` sans passage ou sans distance précédente.
    static func kilometerPassed(from previous: Double?, to current: Double?) -> String? {
        guard let previous, let current else { return nil }
        let before = Int(previous / 1_000)
        let after = Int(current / 1_000)
        return after > before ? kilometres(after) : nil
    }

    // MARK: Écrans

    /// « Localisation refusée : seul le temps est enregistré. »
    static var locationDenied: String {
        String(localized: "Localisation refusée : seul le temps est enregistré.", bundle: .module)
    }

    static var strengthSessionActive: String {
        String(localized: "Une séance de musculation est en cours.", bundle: .module)
    }

    /// « Recherche du signal », « Signal faible », « Prêt ».
    static func gpsStatus(_ quality: RunGPSQuality) -> String {
        switch quality {
        case .searching: String(localized: "Recherche du signal", bundle: .module)
        case .weak: String(localized: "Signal faible", bundle: .module)
        case .ready: String(localized: "Prêt", bundle: .module)
        }
    }

    /// « Footing facile · obj. 30 min », « Sortie longue · obj. 8,5 km », « Course libre ».
    static func goalLine(_ launch: RunLaunch) -> String {
        guard let goal = goal(launch) else { return launch.title }
        return String(localized: "\(launch.title) · obj. \(goal)", bundle: .module)
    }

    /// « 30 min », « 8,5 km » ; `nil` sans objectif.
    static func goal(_ launch: RunLaunch) -> String? {
        if let minutes = launch.targetMinutes, minutes > 0 { return PulseFormat.duration(minutes: minutes) }
        if let km = launch.targetKm, km > 0 {
            return String(localized: "\(PulseFormat.decimal(km, maxFractionDigits: 1)) km", bundle: .module)
        }
        return nil
    }

    /// « Objectif : 30 minutes », « Objectif : 8,5 kilomètres » ; `nil` sans objectif.
    static func goalSpoken(_ launch: RunLaunch) -> String? {
        if let minutes = launch.targetMinutes, minutes > 0 {
            return String(localized: "Objectif : \(PulseSpoken.duration(seconds: minutes * 60))", bundle: .module)
        }
        if let km = launch.targetKm, km > 0 {
            return String(localized: "Objectif : \(PulseSpoken.kilometres(km))", bundle: .module)
        }
        return nil
    }

    /// « 24:13 », « 1:02:05 ».
    static func elapsed(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        return hours > 0 ? "\(hours):\(padded(minutes)):\(padded(rest))" : "\(minutes):\(padded(rest))"
    }

    /// « 24 minutes 13 ».
    static func elapsedSpoken(seconds: Int) -> String {
        PulseSpoken.duration(seconds: seconds)
    }

    /// « 4,38 km » ; « — » sans distance.
    static func distance(_ meters: Double?) -> String {
        guard let meters, meters.isFinite else { return dash }
        return String(localized: "\(PulseFormat.decimal(meters / 1_000, maxFractionDigits: 2)) km", bundle: .module)
    }

    /// « 4,4 kilomètres » ; `nil` sans distance.
    static func distanceSpoken(_ meters: Double?) -> String? {
        guard let meters, meters.isFinite else { return nil }
        return PulseSpoken.kilometres(meters / 1_000)
    }

    /// « 5'31"/km » ; « — » sans allure.
    static func pace(_ secondsPerKm: Int?) -> String {
        guard let secondsPerKm, secondsPerKm > 0 else { return dash }
        return String(localized: "\(splitTime(Double(secondsPerKm)))/km", bundle: .module)
    }

    /// « 5 minutes 31 par kilomètre » ; « pas encore d'allure » sans allure.
    static func paceSpoken(_ secondsPerKm: Int?) -> String {
        guard let secondsPerKm, secondsPerKm > 0 else { return String(localized: "pas encore d'allure", bundle: .module) }
        return PulseSpoken.pace(secondsPerKilometer: secondsPerKm)
    }

    /// « 5'32" » : minutes et secondes d'un temps par km.
    static func splitTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return "\(total / 60)'\(padded(total % 60))\""
    }

    /// « 81 % ».
    static func percent(_ progress: Double) -> String {
        "\(PulseFormat.integer(min(max(progress, 0), 9.99) * 100, unit: nil)) %"
    }

    /// « 152 bpm ».
    static func heartRate(_ bpm: Double) -> String {
        PulseFormat.integer(bpm, unit: "bpm")
    }

    /// « 152 battements par minute ».
    static func heartRateSpoken(_ bpm: Double) -> String {
        String(localized: "\(PulseFormat.integer(bpm, unit: nil)) battements par minute", bundle: .module)
    }

    // MARK: Récap

    /// « Kilomètre 3, 5 minutes 32 secondes » ; le dernier, partiel : « Kilomètre 5 partiel, 420 mètres, 2 minutes 10 secondes ».
    static func splitSpoken(_ split: RunSplit) -> String {
        let time = durationWithSeconds(Int(split.seconds.rounded()))
        guard split.distanceMeters < 999.5 else {
            return String(localized: "Kilomètre \(split.kilometer), \(time)", bundle: .module)
        }
        let meters = PulseSpoken.count(Int(split.distanceMeters.rounded()), singular: String(localized: "mètre", bundle: .module),
                                       plural: String(localized: "mètres", bundle: .module))
        return String(localized: "Kilomètre \(split.kilometer) partiel, \(meters), \(time)", bundle: .module)
    }

    /// « Km 3 », ou « 0,42 km » pour le dernier kilomètre partiel.
    static func splitLabel(_ split: RunSplit) -> String {
        guard split.distanceMeters < 999.5 else { return String(localized: "Km \(split.kilometer)", bundle: .module) }
        return distance(split.distanceMeters)
    }

    /// « 5 minutes 32 secondes », « 1 heure 2 minutes 5 secondes » : l'unité est dite à chaque nombre.
    static func durationWithSeconds(_ seconds: Int) -> String {
        let total = max(0, seconds)
        var parts: [String] = []
        if total >= 3600 {
            parts.append(PulseSpoken.count(total / 3600, singular: String(localized: "heure", bundle: .module),
                                           plural: String(localized: "heures", bundle: .module)))
        }
        if total >= 60 {
            parts.append(PulseSpoken.count((total % 3600) / 60, singular: String(localized: "minute", bundle: .module),
                                           plural: String(localized: "minutes", bundle: .module)))
        }
        parts.append(PulseSpoken.count(total % 60, singular: String(localized: "seconde", bundle: .module),
                                       plural: String(localized: "secondes", bundle: .module)))
        return parts.joined(separator: " ")
    }

    /// « Tracé de la course, 4,4 kilomètres ».
    static func routeLabel(distanceMeters: Double) -> String {
        String(localized: "Tracé de la course, \(PulseSpoken.kilometres(distanceMeters / 1_000))", bundle: .module)
    }

    /// La longueur du tracé, somme des segments entre ses points (formule de haversine), en mètres.
    static func routeDistance(_ points: [RunTrackPoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            let (from, to) = pair
            let lat1 = from.latitude * .pi / 180
            let lat2 = to.latitude * .pi / 180
            let deltaLat = lat2 - lat1
            let deltaLon = (to.longitude - from.longitude) * .pi / 180
            let haversine = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
            return total + 2 * earthRadius * asin(min(1, sqrt(haversine)))
        }
    }

    /// « +42 m » de dénivelé positif.
    static func elevation(_ meters: Double) -> String {
        "+\(PulseFormat.integer(meters, unit: "m"))"
    }

    /// « 42 mètres de dénivelé positif ».
    static func elevationSpoken(_ meters: Double) -> String {
        let count = PulseSpoken.count(Int(meters.rounded()), singular: String(localized: "mètre", bundle: .module),
                                      plural: String(localized: "mètres", bundle: .module))
        return String(localized: "\(count) de dénivelé positif", bundle: .module)
    }

    // MARK: Reprise et oubli

    /// « Course interrompue : enregistrer 4,2 km jusqu'à 7 h 52 ? » ; sans distance, « Course interrompue : l'enregistrer jusqu'à
    /// 7 h 05 ? ».
    public static func recoveryMessage(_ offer: RunRecoveryOffer, calendar: Calendar) -> String {
        let time = clock(offer.lastPointAt, calendar: calendar)
        guard let meters = offer.distanceMeters else {
            return String(localized: "Course interrompue : l'enregistrer jusqu'à \(time) ?", bundle: .module)
        }
        let km = PulseFormat.decimal(meters / 1_000, maxFractionDigits: 1)
        return String(localized: "Course interrompue : enregistrer \(km) km jusqu'à \(time) ?", bundle: .module)
    }

    /// « Course toujours en cours ? Pulse peut la terminer à 7 h 52, ton dernier déplacement. »
    public static func forgottenMessage(_ end: Date, calendar: Calendar) -> String {
        let time = clock(end, calendar: calendar)
        return String(localized: "Course toujours en cours ? Pulse peut la terminer à \(time), ton dernier déplacement.",
                      bundle: .module)
    }

    /// « 7 h 52 », « 7 h 05 ».
    static func clock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(localized: "\(parts.hour ?? 0) h \(padded(parts.minute ?? 0))", bundle: .module)
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
