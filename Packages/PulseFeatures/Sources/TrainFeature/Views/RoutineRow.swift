import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Une routine de « Mes routines » : icône, nom et résumé (« 5 exercices · ~ 65 min · lundi, jeudi »), chevron.
struct RoutineRow: View {
    let routine: RoutineSummary
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let isRun = routine.day.kind == .run
        let palette = PulsePalette.accent(for: theme)
        ObsidianCard {
            HStack(spacing: 12) {
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
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(routine.day.name), \(subtitle)", bundle: .module))
        .accessibilityHint(String(localized: "Ouvre l'éditeur de la routine", bundle: .module))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(TrainIdentifiers.routinePrefix + routine.day.id.uuidString)
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
