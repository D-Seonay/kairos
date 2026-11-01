import PulseContent
import PulseDomain
import SwiftUI

/// Les exercices du contenu, groupés par plan de mouvement.
struct ContentExercisesView: View {
    let model: DataDebugModel

    var body: some View {
        List {
            ForEach(model.exercisesByPattern, id: \.pattern) { group in
                Section("\(group.pattern.localizedName) · \(group.exercises.count)") {
                    ForEach(group.exercises) { exercise in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name.fr).font(.headline)
                            Text("\(exercise.equipment.localizedName) · \(exercise.primaryMuscles.first?.localizedName ?? "–")"
                                 + " · \(exercise.alternatives.count) alt.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Exercices"))
    }
}
