import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La tuile Musculation (opale) et la tuile Course (obsidienne), côte à côte, empilées aux tailles d'accessibilité.
struct TrainTiles: View {
    let model: TrainModel
    let onOpenToday: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            StrengthTile(session: model.today, directory: model.directory, onOpenToday: onOpenToday)
            RunTile(nextRun: model.nextRun, weekday: model.weekday)
        }
    }
}

/// La séance de musculation du jour. M4a ne démarre rien d'ici : toucher la tuile ouvre l'accueil, où la séance se démarre.
private struct StrengthTile: View {
    let session: TodaySession?
    let directory: ExerciseDirectory
    let onOpenToday: () -> Void

    var body: some View {
        Button(action: onOpenToday) {
            OpalCard {
                VStack(alignment: .leading, spacing: 10) {
                    TileIcon(systemName: "dumbbell.fill", foreground: PulsePalette.opal, background: PulsePalette.opalInk)
                    Text(String(localized: "Musculation", bundle: .module))
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.opalMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Musculation : \(subtitle)", bundle: .module))
        .accessibilityHint(String(localized: "Ouvre l'accueil, où démarrer la séance du jour", bundle: .module))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(TrainIdentifiers.strengthTile)
    }

    /// « Push · ajustée · ~ 55 min », « Repos aujourd'hui », « Course aujourd'hui », « Aucun programme actif ».
    private var subtitle: String {
        guard let session else { return String(localized: "Séance du jour", bundle: .module) }
        switch session.plannedDay {
        case .noProgram:
            return String(localized: "Aucun programme actif", bundle: .module)
        case .rest:
            return String(localized: "Repos aujourd'hui", bundle: .module)
        case .run:
            return String(localized: "Course aujourd'hui", bundle: .module)
        case .strength(let day):
            let active = session.activeDay ?? day
            let minutes = SessionSummary.make(day: active, directory: directory).estimatedMinutes
            let duration = String(localized: "~ \(minutes) min", bundle: .module)
            guard session.status == .adjusted else { return String(localized: "\(day.name) · \(duration)", bundle: .module) }
            return String(localized: "\(day.name) · ajustée · \(duration)", bundle: .module)
        }
    }
}

/// La course du jour ou la prochaine de la semaine type. Rien à lancer en M4a : la tuile informe.
private struct RunTile: View {
    let nextRun: NextSession?
    let weekday: Weekday?

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 10) {
                TileIcon(systemName: "figure.run", foreground: PulsePalette.run, background: PulsePalette.runSoft)
                Text(String(localized: "Course", bundle: .module))
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Course : \(subtitle)", bundle: .module))
        .accessibilityIdentifier(TrainIdentifiers.runTile)
    }

    /// « Sortie facile · aujourd'hui », « Fractionné · prévue demain », « Sortie longue · prévue samedi ».
    private var subtitle: String {
        guard let nextRun else { return String(localized: "Aucune course au programme", bundle: .module) }
        let title = nextRun.day.runType?.localizedName ?? nextRun.day.name
        switch daysUntil(nextRun.weekday) {
        case 0: return String(localized: "\(title) · aujourd'hui", bundle: .module)
        case 1: return String(localized: "\(title) · prévue demain", bundle: .module)
        default: return String(localized: "\(title) · prévue \(nextRun.weekday.trainName)", bundle: .module)
        }
    }

    private func daysUntil(_ target: Weekday) -> Int? {
        guard let weekday else { return nil }
        return (target.index - weekday.index + Weekday.allCases.count) % Weekday.allCases.count
    }
}

/// L'icône d'une tuile ou d'une ligne, dans un carré arrondi.
struct TileIcon: View {
    let systemName: String
    let foreground: Color
    let background: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: 38, height: 38)
            .background(background, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous))
            .accessibilityHidden(true)
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
