import PulseDomain
import SwiftUI

/// Les modèles de programme, jour par jour, exercices résolus par le contenu.
struct ContentTemplatesView: View {
    let model: DataDebugModel

    var body: some View {
        List {
            ForEach(model.templates) { template in
                Section(template.name.fr) {
                    ForEach(template.days) { day in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.name.fr).font(.headline)
                            if let run = day.run {
                                Text(Self.runText(run)).font(.footnote).foregroundStyle(.secondary)
                            }
                            ForEach(day.exercises, id: \.exercise) { exercise in
                                exerciseLine(exercise)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Modèles"))
    }

    @ViewBuilder
    private func exerciseLine(_ exercise: TemplateExercise) -> some View {
        if let name = model.exerciseName(for: exercise.exercise) {
            Text("\(name) · \(exercise.sets) × \(exercise.repsMin) à \(exercise.repsMax)")
                .font(.footnote)
        } else {
            Text(exercise.exercise).font(.footnote).foregroundStyle(.red)
        }
    }

    private static func runText(_ run: RunTarget) -> String {
        let type: String = switch run.type {
        case .easy: String(localized: "Course facile")
        case .intervals: String(localized: "Fractionné")
        case .long: String(localized: "Sortie longue")
        }
        if let minutes = run.targetMinutes { return "\(type) · \(minutes) min" }
        if let km = run.targetKm { return "\(type) · \(km.formatted()) km" }
        return type
    }
}
