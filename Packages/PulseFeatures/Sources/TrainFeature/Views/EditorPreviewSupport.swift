#if DEBUG
import SwiftUI

/// Prépare l'onglet en mémoire (programme `templateID`, lundi 2 novembre 2026) puis affiche l'éditeur de programme dans une pile
/// où toucher une routine ouvre son éditeur.
struct ProgramEditorPreviewHost: View {
    var templateID: String? = "ppl-3"
    @State private var train: TrainModel?

    var body: some View {
        NavigationStack {
            if let train {
                ProgramEditorView(model: train.programEditorModel())
                    .navigationDestination(for: TrainDestination.self) { destination in
                        if case .routine(let program, let day) = destination {
                            RoutineEditorView(model: train.routineEditorModel(programID: program, dayID: day))
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .task {
            let model = await TrainPreviewSupport.model(now: TrainPreviewSupport.date(day: 2, hour: 9), templateID: templateID)
            await model.refresh()
            train = model
        }
        .preferredColorScheme(.dark)
    }
}

/// Affiche l'éditeur de la première routine du programme en mémoire.
struct RoutineEditorPreviewHost: View {
    var templateID: String? = "ppl-3"
    @State private var editor: RoutineEditorModel?

    var body: some View {
        NavigationStack {
            if let editor {
                RoutineEditorView(model: editor)
            } else {
                ProgressView()
            }
        }
        .task {
            let train = await TrainPreviewSupport.model(now: TrainPreviewSupport.date(day: 2, hour: 9), templateID: templateID)
            await train.refresh()
            if let programID = train.program?.id, let dayID = train.routines.first?.day.id {
                editor = train.routineEditorModel(programID: programID, dayID: dayID)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Programme : PPL en 3 jours") {
    ProgramEditorPreviewHost()
}

#Preview("Programme : course et musculation") {
    ProgramEditorPreviewHost(templateID: "runner-strength")
}

#Preview("Programme : aucun") {
    ProgramEditorPreviewHost(templateID: nil)
}

#Preview("Routine : Push") {
    RoutineEditorPreviewHost()
}
#endif
