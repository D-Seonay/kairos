import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La semaine type de lundi à dimanche : sur chaque ligne, un menu « routine ou Repos ». Une journée de course d'un modèle
/// adopté s'affiche mais ne se change pas avant M6.
struct WeekAssignmentView: View {
    let program: Program
    let onAssign: (UUID?, Weekday) -> Void

    var body: some View {
        ForEach(Weekday.allCases, id: \.self) { weekday in
            WeekdayRow(weekday: weekday, assigned: assigned(on: weekday), routines: strengthRoutines) { dayID in
                onAssign(dayID, weekday)
            }
        }
    }

    private var strengthRoutines: [RoutineDay] {
        program.days.filter { $0.kind == .strength }.sorted { $0.order < $1.order }
    }

    private func assigned(on weekday: Weekday) -> RoutineDay? {
        guard program.weekLayout.indices.contains(weekday.index), let id = program.weekLayout[weekday.index] else { return nil }
        return program.days.first { $0.id == id }
    }
}

private struct WeekdayRow: View {
    let weekday: Weekday
    let assigned: RoutineDay?
    let routines: [RoutineDay]
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
            if assigned?.kind == .run {
                lockedRun
            } else {
                menu
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TrainIdentifiers.weekdayPrefix + weekday.rawValue)
    }

    private var menu: some View {
        Menu {
            Button(String(localized: "Repos", bundle: .module)) { onAssign(nil) }
            ForEach(routines) { routine in
                Button { onAssign(routine.id) } label: {
                    if routine.id == assigned?.id {
                        Label(routine.name, systemImage: "checkmark")
                    } else {
                        Text(routine.name)
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
        .accessibilityLabel(String(localized: "\(weekday.trainName) : \(assignedName)", bundle: .module))
        .accessibilityHint(String(localized: "Choisir une routine ou le repos", bundle: .module))
    }

    private var lockedRun: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(assignedName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                Text(String(localized: "Course · modifiable plus tard", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
            Spacer(minLength: 0)
            Image(systemName: "lock.fill")
                .font(.footnote)
                .foregroundStyle(PulsePalette.muted)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(weekday.trainName) : \(assignedName), course", bundle: .module))
        .accessibilityHint(String(localized: "Les courses ne se modifient pas encore", bundle: .module))
    }

    /// Le nom de la routine du jour, ou « Repos ».
    private var assignedName: String {
        assigned?.name ?? String(localized: "Repos", bundle: .module)
    }

    /// « 5 exercices » pour une routine, « Jour de repos » sinon.
    private var detail: String {
        guard let assigned else { return String(localized: "Jour de repos", bundle: .module) }
        return String(localized: "\(assigned.exercises.count) exercices", bundle: .module)
    }
}
