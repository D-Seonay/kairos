import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La semaine type de lundi à dimanche : sur chaque ligne, un menu « routine, course ou Repos ». Une course s'y place comme
/// une routine ; elle s'affiche avec son objectif.
struct WeekAssignmentView: View {
    let program: Program
    let onAssign: (UUID?, Weekday) -> Void

    var body: some View {
        ForEach(Weekday.allCases, id: \.self) { weekday in
            WeekdayRow(weekday: weekday, assigned: assigned(on: weekday), days: days) { dayID in
                onAssign(dayID, weekday)
            }
        }
    }

    /// Les routines et les courses du programme, dans son ordre.
    private var days: [RoutineDay] {
        program.days.sorted { $0.order < $1.order }
    }

    private func assigned(on weekday: Weekday) -> RoutineDay? {
        guard program.weekLayout.indices.contains(weekday.index), let id = program.weekLayout[weekday.index] else { return nil }
        return program.days.first { $0.id == id }
    }
}

private struct WeekdayRow: View {
    let weekday: Weekday
    let assigned: RoutineDay?
    let days: [RoutineDay]
    let onAssign: (UUID?) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text(weekday.trainName.localizedCapitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text2)
                .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 84, alignment: .leading)
            menu
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TrainIdentifiers.weekdayPrefix + weekday.rawValue)
    }

    private var menu: some View {
        Menu {
            Button(String(localized: "Repos", bundle: .module)) { onAssign(nil) }
            ForEach(days) { day in
                Button { onAssign(day.id) } label: {
                    if day.id == assigned?.id {
                        Label(menuTitle(day), systemImage: "checkmark")
                    } else {
                        Text(menuTitle(day))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignedName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(assigned == nil ? PulsePalette.muted : PulsePalette.text)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(spokenLabel)
        .accessibilityHint(String(localized: "Choisir une routine, une course ou le repos", bundle: .module))
    }

    /// Le nom de la routine ou de la course du jour, ou « Repos ».
    private var assignedName: String {
        assigned?.name ?? String(localized: "Repos", bundle: .module)
    }

    /// « 5 exercices » pour une routine, « 30 min » ou « Sortie facile · 40 min » pour une course, « Jour de repos » sinon.
    private var detail: String {
        guard let assigned else { return String(localized: "Jour de repos", bundle: .module) }
        return assigned.kind == .run ? TrainText.runSummary(assigned) : TrainText.exercises(assigned.exercises.count)
    }

    /// « lundi : Push », « lundi : Repos » ; une course ajoute son objectif en mots : « lundi : Sortie facile, 30 minutes ».
    private var spokenLabel: String {
        let label = String(localized: "\(weekday.trainName) : \(assignedName)", bundle: .module)
        guard let assigned, assigned.kind == .run else { return label }
        return TrainText.rowSpoken(title: label, detail: TrainText.runSummarySpoken(assigned))
    }

    /// Une routine par son nom ; une course par son nom et son objectif, pour distinguer deux sorties du même type.
    private func menuTitle(_ day: RoutineDay) -> String {
        day.kind == .run ? TrainText.runMenuTitle(day) : day.name
    }
}
