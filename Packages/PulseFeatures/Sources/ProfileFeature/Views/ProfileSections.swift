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

/// Série en cours, score de ce matin et poids tendance, sur trois colonnes (une seule aux tailles d'accessibilité).
struct ProfileTiles: View {
    let summary: ProfileSummary
    let trend: WeightTrend?
    let calendar: Calendar
    let today: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 3)
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach([streakTile, scoreTile, weightTile]) { ProfileTile(content: $0) }
        }
    }

    private var streakTile: ProfileTileContent {
        let weeks = summary.streakWeeks
        return ProfileTileContent(
            title: String(localized: "Série en cours", bundle: .module),
            value: summary.sessionsTotal > 0 ? "\(weeks)" : nil,
            unit: weeks < 2 ? String(localized: "semaine", bundle: .module) : String(localized: "semaines", bundle: .module),
            spoken: ProfileText.weeks(weeks),
            emptyText: String(localized: "Pas encore de séance", bundle: .module))
    }

    private var scoreTile: ProfileTileContent {
        ProfileTileContent(
            title: String(localized: "Score du matin", bundle: .module),
            value: summary.morningScore.map { PulseFormat.integer($0, unit: nil) },
            unit: String(localized: "sur 100", bundle: .module),
            emptyText: String(localized: "Pas encore de score aujourd'hui", bundle: .module))
    }

    /// La tendance, datée quand la dernière pesée a plus de 14 jours.
    private var weightTile: ProfileTileContent {
        let current = trend?.current
        var unit = String(localized: "kg", bundle: .module)
        if trend?.isStale == true, let last = trend?.lastMeasured {
            unit = String(localized: "kg au \(ProfileText.shortDate(last, calendar: calendar, today: today))", bundle: .module)
        }
        return ProfileTileContent(
            title: String(localized: "Poids", bundle: .module),
            value: current.map { PulseFormat.decimal($0, maxFractionDigits: 1) }, unit: unit,
            emptyText: String(localized: "Pas encore de pesée", bundle: .module))
    }
}

/// Une tuile : VoiceOver la lit d'une phrase.
private struct ProfileTile: View {
    let content: ProfileTileContent
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 30

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .pulseEyebrow()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let value = content.value {
                    Text(value)
                        .font(PulseFont.score(size: valueSize))
                        .foregroundStyle(PulsePalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
        guard let value = content.value else { return [content.title, content.emptyText].joined(separator: ", ") }
        let reading = content.spoken ?? ([value] + (content.unit.map { [$0] } ?? [])).joined(separator: " ")
        return [content.title, reading].joined(separator: ", ")
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
            .accessibilityElement(children: .combine)
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
            Text(caption(trend))
                .font(.caption)
                .foregroundStyle(PulsePalette.text2)
        }
        if let change = trend.change30Days {
            Text(ProfileText.weightChange(change))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text)
        }
    }

    /// « tendance sur 7 jours », ou « dernière mesure le 12 nov. » sans pesée depuis 14 jours (spec M7 §14).
    private func caption(_ trend: WeightTrend) -> String {
        if trend.isStale, let last = trend.lastMeasured {
            let day = ProfileText.shortDate(last, calendar: calendar, today: today)
            return String(localized: "dernière mesure le \(day)", bundle: .module)
        }
        return String(localized: "tendance sur 7 jours", bundle: .module)
    }
}

// MARK: - Mur des records

/// Les levés de base et les trois chronos de course ; « Tout voir » ouvre Stats → Records.
struct RecordsWall: View {
    let lifts: [StrengthRecordLine]
    let runs: [RunBest]
    let calendar: Calendar
    let today: Date
    let onOpenRecords: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(String(localized: "Records", bundle: .module)) {
                Button(String(localized: "Tout voir", bundle: .module), action: onOpenRecords)
                    .buttonStyle(PillButtonStyle())
            }
            ObsidianCard {
                VStack(alignment: .leading, spacing: 0) {
                    if lifts.isEmpty {
                        ProfileEmptyNote(
                            heading: String(localized: "Pas encore de record de force", bundle: .module),
                            reason: String(localized: "squat, développé couché, soulevé de terre et développé militaire",
                                           bundle: .module))
                            .padding(.bottom, 10)
                    } else {
                        ForEach(lifts) { line in
                            row(title: line.name, detail: ProfileText.shortDate(line.date, calendar: calendar, today: today),
                                value: ProfileText.recordValue(line))
                        }
                    }
                    Divider().overlay(PulsePalette.line)
                    ForEach(runs) { run in
                        row(title: ProfileText.runTitle(run.distance),
                            detail: run.date.map { ProfileText.shortDate($0, calendar: calendar, today: today) },
                            value: run.seconds.map { ProfileText.raceTime(seconds: $0) })
                    }
                }
            }
        }
    }

    /// Sans valeur (une distance jamais couverte) : « Pas encore couru ».
    private func row(title: String, detail: String?, value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(PulseFont.value(.headline))
                    .foregroundStyle(PulsePalette.text)
            } else {
                Text(String(localized: "Pas encore couru", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Vitrine

/// Les badges obtenus avec leur date, puis le prochain de chaque famille avec sa progression.
struct BadgeShelfSection: View {
    let shelf: BadgeShelf
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(String(localized: "Vitrine", bundle: .module))
            ObsidianCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(shelf.earned) { badge in
                        row(badge) {
                            Text(badge.earnedAt.map { ProfileText.earnedDate($0, calendar: calendar) } ?? "")
                                .font(.caption)
                                .foregroundStyle(PulsePalette.text2)
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
        .accessibilityElement(children: .combine)
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

/// Statistiques (l'onglet Stats), Compléments, Paramètres et Mes données.
struct ProfileLinks: View {
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
                 detail: String(localized: "Stockage, export et suppression", bundle: .module))
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
private struct ProfileEmptyNote: View {
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
