import Foundation
import PulseDesignSystem
import PulseDomain

/// Les données affichées par le widget Séance du jour : titre, statut d'ajustement, métadonnées
/// et cartographie musculaire.
public struct TodaySessionWidgetContent: Sendable, Equatable {
    public static let kind = "TodaySessionWidget"

    public static var displayName: String {
        String(localized: "Séance du jour", bundle: .module)
    }

    public static var summary: String {
        String(localized: "Ta séance prévue, ses muscles ciblés et son volume.", bundle: .module)
    }

    public var title: String
    public var isAdjusted: Bool
    public var isLightened: Bool
    public var isRest: Bool
    public var metaText: String
    public var buttonText: String
    public var muscleLevels: [MuscleMapRegion: Int]
    public var accessoryTitle: String
    public var accessorySubtitle: String
    public var accessoryDetail: String
    public var accessibilityLabel: String

    public init(
        title: String,
        isAdjusted: Bool,
        isLightened: Bool,
        isRest: Bool,
        metaText: String,
        buttonText: String,
        muscleLevels: [MuscleMapRegion: Int],
        accessoryTitle: String,
        accessorySubtitle: String,
        accessoryDetail: String,
        accessibilityLabel: String
    ) {
        self.title = title
        self.isAdjusted = isAdjusted
        self.isLightened = isLightened
        self.isRest = isRest
        self.metaText = metaText
        self.buttonText = buttonText
        self.muscleLevels = muscleLevels
        self.accessoryTitle = accessoryTitle
        self.accessorySubtitle = accessorySubtitle
        self.accessoryDetail = accessoryDetail
        self.accessibilityLabel = accessibilityLabel
    }

    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> TodaySessionWidgetContent {
        guard let snapshot, calendar.isDate(snapshot.day, inSameDayAs: date) else {
            return sample(at: date, calendar: calendar)
        }

        guard let sessionTitle = snapshot.sessionTitle, !sessionTitle.isEmpty else {
            let restTitle = String(localized: "Jour de repos", bundle: .module)
            let restMeta = String(localized: "Récupération active", bundle: .module)
            let spoken = String(localized: "Séance du jour : jour de repos", bundle: .module)
            return TodaySessionWidgetContent(
                title: restTitle,
                isAdjusted: false,
                isLightened: false,
                isRest: true,
                metaText: restMeta,
                buttonText: String(localized: "Voir", bundle: .module),
                muscleLevels: [:],
                accessoryTitle: restTitle,
                accessorySubtitle: restMeta,
                accessoryDetail: String(localized: "Aucune séance", bundle: .module),
                accessibilityLabel: spoken
            )
        }

        let isAdjusted = snapshot.isLightened
        let meta = String(localized: "14 séries · 55 min · RPE 7,5", bundle: .module)
        let levels = defaultMuscleLevels(for: sessionTitle)
        let sub = isAdjusted
            ? String(localized: "14 séries · allégée", bundle: .module)
            : String(localized: "14 séries · 55 min", bundle: .module)
        let detail = String(localized: "RPE max 7,5", bundle: .module)
        let spoken = String(
            localized: "Séance du jour : \(sessionTitle), 14 séries, 55 minutes, RPE 7,5",
            bundle: .module
        )

        return TodaySessionWidgetContent(
            title: sessionTitle,
            isAdjusted: isAdjusted,
            isLightened: snapshot.isLightened,
            isRest: false,
            metaText: meta,
            buttonText: String(localized: "Démarrer", bundle: .module),
            muscleLevels: levels,
            accessoryTitle: sessionTitle,
            accessorySubtitle: sub,
            accessoryDetail: detail,
            accessibilityLabel: spoken
        )
    }

    public static func sample(at date: Date, calendar: Calendar) -> TodaySessionWidgetContent {
        let title = String(localized: "Pectoraux et triceps", bundle: .module)
        let meta = String(localized: "14 séries · 55 min · RPE 7,5", bundle: .module)
        let sub = String(localized: "14 séries · allégée", bundle: .module)
        let detail = String(localized: "RPE max 7,5", bundle: .module)
        let spoken = String(
            localized: "Séance du jour : \(title), 14 séries, 55 minutes, RPE 7,5",
            bundle: .module
        )

        return TodaySessionWidgetContent(
            title: title,
            isAdjusted: true,
            isLightened: true,
            isRest: false,
            metaText: meta,
            buttonText: String(localized: "Démarrer", bundle: .module),
            muscleLevels: [.chest: 4, .triceps: 3, .frontDeltoid: 2],
            accessoryTitle: title,
            accessorySubtitle: sub,
            accessoryDetail: detail,
            accessibilityLabel: spoken
        )
    }

    private static func defaultMuscleLevels(for sessionTitle: String) -> [MuscleMapRegion: Int] {
        let lower = sessionTitle.lowercased()
        if lower.contains("push") || lower.contains("pec") || lower.contains("pector") {
            return [.chest: 4, .triceps: 3, .frontDeltoid: 2]
        }
        if lower.contains("pull") || lower.contains("dos") || lower.contains("tirage") {
            return [.upperBack: 4, .lats: 3, .biceps: 2]
        }
        if lower.contains("leg") || lower.contains("jambe") || lower.contains("squat") {
            return [.quadriceps: 4, .hamstrings: 3, .glutes: 3, .calves: 2]
        }
        if lower.contains("run") || lower.contains("course") || lower.contains("endurance") {
            return [.quadriceps: 3, .calves: 3, .glutes: 2]
        }
        return [.chest: 4, .triceps: 3, .frontDeltoid: 2]
    }
}
