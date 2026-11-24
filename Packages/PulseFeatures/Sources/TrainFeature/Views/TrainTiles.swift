import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La tuile Musculation (opale) et la tuile Course (obsidienne), côte à côte, empilées aux tailles d'accessibilité.
struct TrainTiles: View {
    let model: TrainModel
    let onOpenToday: () -> Void
    /// Lance la séance du jour ; `nil` quand il n'y a pas de séance de musculation à lancer aujourd'hui.
    let onStart: (() -> Void)?
    /// Lance la course du jour, ou une course libre sans course aujourd'hui.
    var onStartRun: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            StrengthTile(subtitle: model.strengthSubtitle, spokenSubtitle: model.strengthSubtitleSpoken,
                         onOpenToday: onOpenToday, onStart: onStart)
            RunTile(nextRun: model.nextRun, daysUntil: model.nextRun.flatMap { model.daysUntil($0.weekday) },
                     startLabel: model.runStartLabel, onStart: onStartRun)
        }
    }
}

/// La séance de musculation du jour : toucher la tuile ouvre l'accueil, « Démarrer » lance la séance (un bouton à part).
private struct StrengthTile: View {
    let subtitle: String
    let spokenSubtitle: String
    let onOpenToday: () -> Void
    let onStart: (() -> Void)?

    var body: some View {
        OpalCard {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: onOpenToday) {
                    VStack(alignment: .leading, spacing: 10) {
                        IconChip(systemName: "dumbbell.fill", tone: .inverted)
                        Text(String(localized: "Musculation", bundle: .module))
                            .font(.headline)
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.opalMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Musculation : \(spokenSubtitle)", bundle: .module))
                .accessibilityHint(String(localized: "Ouvre l'accueil, où démarrer la séance du jour", bundle: .module))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(TrainIdentifiers.strengthTile)
                if let onStart {
                    Button(String(localized: "Démarrer", bundle: .module), action: onStart)
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityLabel(String(localized: "Démarrer la séance du jour", bundle: .module))
                        .accessibilityIdentifier(TrainIdentifiers.strengthStart)
                }
            }
        }
    }
}

/// La course du jour ou la prochaine de la semaine type. « Courir » lance celle d'aujourd'hui, ou une course libre quand elle
/// tombe un autre jour : la tuile informe, le bouton à part lance.
private struct RunTile: View {
    let nextRun: NextSession?
    /// Les jours d'ici la prochaine course : 0 aujourd'hui, 1 demain.
    let daysUntil: Int?
    /// Ce que le bouton lance, dit à VoiceOver.
    let startLabel: String
    let onStart: () -> Void

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    IconChip(systemName: "figure.run")
                    Text(String(localized: "Course", bundle: .module))
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Course : \(subtitle)", bundle: .module))
                .accessibilityIdentifier(TrainIdentifiers.runTile)
                Button(String(localized: "Courir", bundle: .module), action: onStart)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel(startLabel)
                    .accessibilityIdentifier(TrainIdentifiers.runStart)
            }
        }
    }

    /// « Sortie facile · aujourd'hui », « Fractionné · prévue demain », « Sortie longue · prévue samedi ».
    private var subtitle: String {
        guard let nextRun else { return String(localized: "Aucune course au programme", bundle: .module) }
        let title = nextRun.day.runType?.localizedName ?? nextRun.day.name
        switch daysUntil {
        case 0: return String(localized: "\(title) · aujourd'hui", bundle: .module)
        case 1: return String(localized: "\(title) · prévue demain", bundle: .module)
        default: return String(localized: "\(title) · prévue \(nextRun.weekday.trainName)", bundle: .module)
        }
    }
}

extension Weekday {
    /// Le jour en toutes lettres et en minuscules, pour une phrase : « mercredi ».
    var trainName: String {
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
