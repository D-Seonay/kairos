import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

// MARK: - Tuiles

/// Une tuile : l'étiquette, le gros chiffre et son unité ; sans valeur, une phrase précise à la place (jamais un zéro).
private struct ProfileTileContent: Identifiable {
    let title: String
    let value: String?
    var unit: String?
    /// Ce que VoiceOver lit à la place de la valeur et de son unité.
    var spoken: String?
    let emptyText: String

    var id: String { title }
}

/// Série en cours et score de ce matin, sur deux colonnes (une seule aux tailles d'accessibilité). Le poids n'a pas de tuile : la
/// carte « Poids et corps », juste dessous, le donne déjà.
struct ProfileTiles: View {
    let summary: ProfileSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach([streakTile, scoreTile]) { ProfileTile(content: $0) }
        }
    }

    private var streakTile: ProfileTileContent {
        let weeks = summary.streakWeeks
        return ProfileTileContent(
            title: String(localized: "Série en cours", bundle: .module),
            value: summary.sessionsTotal > 0 ? "\(weeks)" : nil,
            unit: ProfileText.weeksUnit(weeks),
            spoken: ProfileText.weeks(weeks),
            emptyText: String(localized: "Pas encore de séance", bundle: .module))
    }

    /// Un score estimé d'après le questionnaire du matin le dit, comme sur l'accueil.
    private var scoreTile: ProfileTileContent {
        ProfileTileContent(
            title: String(localized: "Score du matin", bundle: .module),
            value: summary.morningScore.map { PulseFormat.integer($0, unit: nil) },
            unit: summary.morningScoreIsEstimated
                ? String(localized: "sur 100 · Estimé", bundle: .module)
                : String(localized: "sur 100", bundle: .module),
            spoken: summary.morningScore.map { ProfileText.morningScoreSpoken($0, isEstimated: summary.morningScoreIsEstimated) },
            emptyText: String(localized: "Pas encore de score aujourd'hui", bundle: .module))
    }
}

/// Une tuile : VoiceOver la lit d'une phrase.
private struct ProfileTile: View {
    let content: ProfileTileContent
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 30
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Aux tailles d'accessibilité, ni limite de lignes ni réduction : le titre et la valeur passent à la ligne entiers.
    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        return ObsidianCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .pulseEyebrow()
                    .lineLimit(isLarge ? nil : 2)
                    .minimumScaleFactor(isLarge ? 1 : 0.8)
                if let value = content.value {
                    Text(value)
                        .font(PulseFont.score(size: valueSize))
                        .foregroundStyle(PulsePalette.text)
                        .lineLimit(isLarge ? nil : 1)
                        .minimumScaleFactor(isLarge ? 1 : 0.5)
                    if let unit = content.unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(PulsePalette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(content.emptyText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        ProfileText.tileSpoken(title: content.title, value: content.value, unit: content.unit, spoken: content.spoken,
                               emptyText: content.emptyText)
    }
}

// MARK: - Poids et corps

/// La tendance, sa variation sur 30 jours et la dernière masse grasse ; ouvre l'écran Poids.
struct WeightCard: View {
    let trend: WeightTrend?
    let calendar: Calendar
    let today: Date

    var body: some View {
        NavigationLink(value: ProfileDestination.weight) {
            ObsidianCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "Poids et corps", bundle: .module))
                            .pulseEyebrow(PulsePalette.text2)
                        Spacer(minLength: 8)
                        RowChevron()
                    }
                    if let trend, let current = trend.current {
                        weight(current, trend: trend)
                    } else {
                        ProfileEmptyNote(heading: String(localized: "Pas encore de pesée", bundle: .module),
                                         reason: String(localized: "ajoute une pesée ou autorise le poids dans Apple Santé",
                                                        bundle: .module))
                    }
                    if let fat = trend?.latestBodyFat {
                        Text(String(localized: "Masse grasse \(ProfileText.bodyFat(fat, calendar: calendar, today: today))",
                                    bundle: .module))
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ProfileText.weightCardSpoken(trend: trend, calendar: calendar, today: today))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint(String(localized: "Ouvre l'écran Poids", bundle: .module))
    }

    @ViewBuilder
    private func weight(_ current: Double, trend: WeightTrend) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ProfileText.weight(current))
                .font(PulseFont.value(.title))
                .foregroundStyle(PulsePalette.text)
            Text(ProfileText.trendCaption(trend, calendar: calendar, today: today))
                .font(.caption)
                .foregroundStyle(PulsePalette.text2)
        }
        if let change = trend.change30Days {
            Text(ProfileText.weightChange(change))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text)
        }
    }
}

// MARK: - Vitrine

/// Les badges obtenus avec leur date, puis le prochain de chaque famille avec sa progression.
struct BadgeShelfSection: View {
    let shelf: BadgeShelf
    let calendar: Calendar
    let today: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(String(localized: "Vitrine", bundle: .module))
            ObsidianCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(shelf.earned) { badge in
                        row(badge) {
                            if let earnedAt = badge.earnedAt {
                                // Une coche en plus de la date : un badge obtenu se distingue sans dépendre de la teinte.
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .accessibilityHidden(true)
                                    Text(ProfileText.shortDate(earnedAt, calendar: calendar, today: today))
                                }
                                .font(.caption)
                                .foregroundStyle(PulsePalette.text2)
                            }
                        }
                    }
                    if !shelf.earned.isEmpty && !shelf.next.isEmpty {
                        Divider().overlay(PulsePalette.line)
                    }
                    ForEach(shelf.next) { badge in
                        row(badge) {
                            VStack(alignment: .leading, spacing: 4) {
                                BadgeProgressBar(progress: badge.progress)
                                Text(ProfileText.badgeProgress(badge))
                                    .font(.caption)
                                    .foregroundStyle(PulsePalette.text2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func row(_ badge: Badge, @ViewBuilder detail: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            IconChip(systemName: Self.icon(badge.kind), tone: badge.earnedAt == nil ? .neutral : .inverted, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(ProfileText.badgeTitle(badge.kind))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                detail()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ProfileText.badgeAccessibility(badge, calendar: calendar, today: today))
    }

    private static func icon(_ kind: BadgeKind) -> String {
        switch kind {
        case .streak: "flame.fill"
        case .sessions: "dumbbell.fill"
        case .firstFullMonth: "calendar"
        }
    }
}

/// Une barre fine, encre sur papier : pas de couleur de signal pour une progression.
private struct BadgeProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(PulsePalette.ink.opacity(0.1))
                Capsule().fill(PulsePalette.ink).frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

// MARK: - Liens

/// Statistiques (l'onglet Stats), Compléments, Paramètres et Mes données, avec l'alerte d'une synchronisation iCloud en échec.
struct ProfileLinks: View {
    /// Une synchronisation iCloud en échec depuis plus d'un jour ; elle remplace le détail de « Mes données ».
    var syncWarning: String?
    let onOpenStats: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onOpenStats) {
                PulseRow(systemImage: "chart.bar.xaxis", title: String(localized: "Statistiques", bundle: .module),
                         detail: String(localized: "Charge, biométrie, muscles, assiduité et records", bundle: .module))
            }
            .buttonStyle(PressableButtonStyle())
            link(.supplements, systemImage: "pills", title: String(localized: "Compléments", bundle: .module),
                 detail: String(localized: "Prises du jour, stock et régularité", bundle: .module))
            link(.settings, systemImage: "gearshape", title: String(localized: "Paramètres", bundle: .module),
                 detail: String(localized: "Profil, Apple Santé, séance et notifications", bundle: .module))
            link(.myData, systemImage: "externaldrive", title: String(localized: "Mes données", bundle: .module),
                 detail: syncWarning ?? String(localized: "Stockage, export et suppression", bundle: .module))
        }
        .padding(.top, 8)
    }

    private func link(_ destination: ProfileDestination, systemImage: String, title: String, detail: String) -> some View {
        NavigationLink(value: destination) {
            PulseRow(systemImage: systemImage, title: title, detail: detail)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Une absence et sa raison, à la place d'un chiffre : jamais un zéro (spec M7 §2).
struct ProfileEmptyNote: View {
    let heading: String
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heading)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text2)
            Text(reason)
                .font(.caption)
                .foregroundStyle(PulsePalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
