import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Les routines et les courses du programme actif : chacune ouvre son éditeur au toucher, se duplique et se supprime de la
/// même façon. Dessous, « Ajouter une routine », « Ajouter une course » (créée d'un geste, prête à courir) et l'entrée vers
/// l'historique.
struct ProgramDaysSection: View {
    let program: Program
    let onAddRoutine: () -> Void
    let onAddRun: () -> Void
    let onDuplicate: (RoutineDay) -> Void
    let onRemove: (RoutineDay) -> Void

    var body: some View {
        Section {
            ForEach(program.days.sorted { $0.order < $1.order }) { day in
                row(day)
                    .swipeActions(edge: .trailing) {
                        Button(String(localized: "Supprimer", bundle: .module), role: .destructive) { onRemove(day) }
                        Button(String(localized: "Dupliquer", bundle: .module)) { onDuplicate(day) }
                            .tint(PulsePalette.muted)
                    }
                    .contextMenu {
                        Button(String(localized: "Dupliquer", bundle: .module), systemImage: "plus.square.on.square") {
                            onDuplicate(day)
                        }
                        Button(String(localized: "Supprimer", bundle: .module), systemImage: "trash", role: .destructive) {
                            onRemove(day)
                        }
                    }
            }
            Button(action: onAddRoutine) {
                Label(String(localized: "Ajouter une routine", bundle: .module), systemImage: "plus")
            }
            .frame(minHeight: 44)
            Button(action: onAddRun) {
                Label(String(localized: "Ajouter une course", bundle: .module), systemImage: "figure.run")
            }
            .frame(minHeight: 44)
            .accessibilityHint(String(localized: "Ajoute une sortie facile de 30 minutes, à régler ensuite", bundle: .module))
            .accessibilityIdentifier(TrainIdentifiers.runDayAdd)
            NavigationLink(value: TrainDestination.history) {
                Label(String(localized: "Depuis une séance passée", bundle: .module), systemImage: "clock.arrow.circlepath")
            }
            .frame(minHeight: 44)
            .accessibilityHint(String(localized: "Ouvre l'historique : choisis une séance à enregistrer comme routine", bundle: .module))
            .accessibilityIdentifier(TrainIdentifiers.routineFromSession)
        } header: {
            Text(String(localized: "Routines et courses", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// Une routine ouvre l'éditeur de routine ; une course, l'éditeur de course, et porte un coureur pour se distinguer.
    @ViewBuilder
    private func row(_ day: RoutineDay) -> some View {
        if day.kind == .run {
            NavigationLink(value: TrainDestination.run(program: program.id, day: day.id)) {
                LabeledRow(title: day.name, detail: TrainText.runSummary(day), systemImage: "figure.run")
            }
            .accessibilityLabel(TrainText.rowSpoken(title: day.name, detail: TrainText.runSummarySpoken(day)))
            .accessibilityHint(String(localized: "Ouvre l'éditeur de la course", bundle: .module))
            .accessibilityIdentifier(TrainIdentifiers.runDayPrefix + day.id.uuidString)
        } else {
            NavigationLink(value: TrainDestination.routine(program: program.id, day: day.id)) {
                LabeledRow(title: day.name, detail: TrainText.exercises(day.exercises.count), systemImage: nil)
            }
        }
    }
}

/// Une ligne de liste : titre, détail et une icône facultative à droite.
struct LabeledRow: View {
    let title: String
    let detail: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}
