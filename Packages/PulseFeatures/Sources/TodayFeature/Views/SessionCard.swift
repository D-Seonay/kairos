import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La carte « Séance du jour » : musculation avec sa mini-carte musculaire, course, repos ou aucun programme.
struct SessionCard: View {
    let plannedDay: PlannedDay
    let summary: SessionSummary?

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                switch plannedDay {
                case .strength(let day): strength(day)
                case .run(let day): run(day)
                case .rest(let next): rest(next)
                case .noProgram: noProgram
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Musculation

    @ViewBuilder
    private func strength(_ day: RoutineDay) -> some View {
        eyebrow(String(localized: "Séance du jour", bundle: .module))
        title(day.name)
        if let summary {
            SessionOverview(summary: summary)
        }
    }

    // MARK: - Course

    @ViewBuilder
    private func run(_ day: RoutineDay) -> some View {
        eyebrow(String(localized: "Séance du jour", bundle: .module))
        HStack(spacing: 10) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundStyle(PulsePalette.run)
                .accessibilityHidden(true)
            title(day.runType?.localizedName ?? day.name)
        }
        if let target = Self.runTarget(day) {
            Text(target)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
        }
    }

    /// « 40 min », « 8 km » ou « 40 min · 8 km » ; `nil` sans cible.
    static func runTarget(_ day: RoutineDay) -> String? {
        var parts: [String] = []
        if let minutes = day.runTargetMinutes {
            parts.append(PulseFormat.duration(minutes: minutes))
        }
        if let km = day.runTargetKm {
            let number = km.formatted(.number.locale(Locale(identifier: "fr_FR")).precision(.fractionLength(0...1)))
            parts.append(String(localized: "\(number) km", bundle: .module))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Repos

    @ViewBuilder
    private func rest(_ next: NextSession?) -> some View {
        eyebrow(String(localized: "Séance du jour", bundle: .module))
        title(String(localized: "Repos", bundle: .module))
        Text(next.map(Self.nextSessionText) ?? String(localized: "Aucune autre séance prévue cette semaine.", bundle: .module))
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text2)
    }

    /// « Prochaine séance : Pull, mercredi ».
    static func nextSessionText(_ next: NextSession) -> String {
        String(localized: "Prochaine séance : \(next.day.name), \(next.weekday.todayName)", bundle: .module)
    }

    // MARK: - Sans programme

    @ViewBuilder
    private var noProgram: some View {
        eyebrow(String(localized: "Séance du jour", bundle: .module))
        title(String(localized: "Aucune séance prévue.", bundle: .module))
        Text(String(localized: "L'éditeur de routines arrive avec la séance en direct.", bundle: .module))
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text2)
    }

    // MARK: - Éléments

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PulsePalette.muted)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(PulsePalette.text)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(TodayIdentifiers.sessionTitle)
    }
}

/// Mini-carte musculaire, séries, durée, RPE maximum et trois muscles principaux ; empilés aux tailles d'accessibilité.
private struct SessionOverview: View {
    let summary: SessionSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout {
            MuscleMapView(levels: MuscleIntensity.levels(weights: summary.muscleWeights), label: musclesLabel, height: 110)
            VStack(alignment: .leading, spacing: 6) {
                Text(statsText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PulsePalette.text)
                if !summary.topMuscles.isEmpty {
                    Text(summary.topMuscles.map(\.localizedName).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
    }

    private var musclesLabel: String {
        let names = summary.topMuscles.map(\.localizedName).joined(separator: ", ")
        return String(localized: "Muscles sollicités : \(names)", bundle: .module)
    }

    /// « 19 séries · ~ 55 min · RPE max 8 ».
    private var statsText: String {
        let sets = String(localized: "\(summary.setCount) séries", bundle: .module)
        let duration = String(localized: "~ \(PulseFormat.duration(minutes: summary.estimatedMinutes))", bundle: .module)
        let rpe = summary.maxRPE.formatted(.number.locale(Locale(identifier: "fr_FR")).precision(.fractionLength(0...1)))
        return [sets, duration, String(localized: "RPE max \(rpe)", bundle: .module)].joined(separator: " · ")
    }
}

extension Weekday {
    /// Le jour en toutes lettres et en minuscules, pour une phrase : « mercredi ».
    var todayName: String {
        switch self {
        case .monday: String(localized: "lundi", bundle: .module)
        case .tuesday: String(localized: "mardi", bundle: .module)
        case .wednesday: String(localized: "mercredi", bundle: .module)
        case .thursday: String(localized: "jeudi", bundle: .module)
        case .friday: String(localized: "vendredi", bundle: .module)
        case .saturday: String(localized: "samedi", bundle: .module)
        case .sunday: String(localized: "dimanche", bundle: .module)
        }
    }
}
