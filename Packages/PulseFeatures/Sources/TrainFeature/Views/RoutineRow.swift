import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Une routine de « Mes routines » : icône, nom et résumé (« 5 exercices · ~ 65 min · lundi, jeudi »), chevron vers l'éditeur,
/// et « Lancer » (musculation seulement), un bouton à part de la touche qui ouvre l'éditeur.
struct RoutineRow: View {
    let routine: RoutineSummary
    /// Le programme dont la routine s'ouvre dans l'éditeur ; `nil` pour une course, qui ne se modifie pas avant M6.
    let programID: UUID?
    /// Lance la routine ; `nil` pour une course, qui ne se démarre pas avant M6.
    let onLaunch: (() -> Void)?
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        ObsidianCard {
            layout {
                summary
                if let onLaunch {
                    Button(action: onLaunch) { LaunchLabel(text: String(localized: "Lancer", bundle: .module)) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Lancer \(routine.day.name)", bundle: .module))
                        .accessibilityIdentifier(TrainIdentifiers.routineLaunchPrefix + routine.day.id.uuidString)
                }
            }
        }
    }

    /// L'icône, le nom et le résumé : ouvre l'éditeur quand la routine s'y prête.
    @ViewBuilder
    private var summary: some View {
        if let programID {
            NavigationLink(value: TrainDestination.routine(program: programID, day: routine.day.id)) {
                summaryContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "\(routine.day.name), \(subtitle)", bundle: .module))
            .accessibilityHint(String(localized: "Ouvre l'éditeur de la routine", bundle: .module))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(TrainIdentifiers.routinePrefix + routine.day.id.uuidString)
        } else {
            summaryContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "\(routine.day.name), \(subtitle)", bundle: .module))
                .accessibilityIdentifier(TrainIdentifiers.routinePrefix + routine.day.id.uuidString)
        }
    }

    private var summaryContent: some View {
        let isRun = routine.day.kind == .run
        let palette = PulsePalette.accent(for: theme)
        return HStack(spacing: 12) {
            TileIcon(systemName: isRun ? "figure.run" : "dumbbell.fill",
                     foreground: isRun ? PulsePalette.run : Color(palette.accent),
                     background: isRun ? PulsePalette.runSoft : palette.soft)
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.day.name)
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if programID != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    /// Musculation : exercices, durée estimée, jours. Course : type, objectif, jours.
    private var subtitle: String {
        var parts: [String] = []
        if routine.day.kind == .run {
            parts.append(routine.day.runType?.localizedName ?? String(localized: "Course", bundle: .module))
            if let target = runTarget { parts.append(target) }
        } else {
            parts.append(String(localized: "\(routine.exerciseCount) exercices", bundle: .module))
            parts.append(String(localized: "~ \(routine.estimatedMinutes) min", bundle: .module))
        }
        parts.append(days)
        return parts.joined(separator: " · ")
    }

    private var runTarget: String? {
        if let minutes = routine.day.runTargetMinutes {
            return String(localized: "\(minutes) min", bundle: .module)
        }
        guard let km = routine.day.runTargetKm else { return nil }
        let distance = km.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "fr_FR")))
        return String(localized: "\(distance) km", bundle: .module)
    }

    /// « lundi, jeudi » ; « hors semaine type » pour une routine qu'aucun jour ne planifie.
    private var days: String {
        guard !routine.weekdays.isEmpty else { return String(localized: "hors semaine type", bundle: .module) }
        return routine.weekdays.map(\.trainName).joined(separator: ", ")
    }
}

/// Le texte d'un bouton « Lancer » : accentué, dans une pastille, avec une cible d'au moins 44 pt.
struct LaunchLabel: View {
    let text: String
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(palette.accent))
            .padding(.horizontal, 14)
            .frame(minWidth: 44, minHeight: 44)
            .background(palette.soft, in: Capsule())
            .contentShape(Capsule())
    }
}
