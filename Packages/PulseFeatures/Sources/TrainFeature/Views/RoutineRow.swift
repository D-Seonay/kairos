import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Une routine de « Mes routines » : icône, nom et résumé (« 5 exercices · ~ 65 min · lundi, jeudi »), chevron vers l'éditeur,
/// et « Lancer » (musculation seulement), une pastille à part de la touche qui ouvre l'éditeur.
struct RoutineRow: View {
    let routine: RoutineSummary
    /// Le programme dont la routine s'ouvre dans l'éditeur ; `nil` pour une course, qui ne se modifie pas avant M6.
    let programID: UUID?
    /// Lance la routine ; `nil` pour une course, qui ne se démarre pas avant M6.
    let onLaunch: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        ObsidianCard {
            layout {
                summary
                if let onLaunch {
                    Button(action: onLaunch) {
                        Label(String(localized: "Lancer", bundle: .module), systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
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
            .buttonStyle(PressableButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "\(routine.day.name), \(spokenSubtitle)", bundle: .module))
            .accessibilityHint(String(localized: "Ouvre l'éditeur de la routine", bundle: .module))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(TrainIdentifiers.routinePrefix + routine.day.id.uuidString)
        } else {
            summaryContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "\(routine.day.name), \(spokenSubtitle)", bundle: .module))
                .accessibilityIdentifier(TrainIdentifiers.routinePrefix + routine.day.id.uuidString)
        }
    }

    private var summaryContent: some View {
        let isRun = routine.day.kind == .run
        return HStack(spacing: 12) {
            IconChip(systemName: isRun ? "figure.run" : "dumbbell.fill", tone: isRun ? .neutral : .accent)
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
                RowChevron()
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    /// Musculation : exercices, durée estimée, jours. Course : type, objectif, jours.
    private var subtitle: String {
        TrainText.routineSubtitle(routine)
    }

    /// Le même résumé dit en mots : « environ 55 minutes » plutôt que « ~ 55 min ».
    private var spokenSubtitle: String {
        TrainText.routineSubtitleSpoken(routine)
    }
}
