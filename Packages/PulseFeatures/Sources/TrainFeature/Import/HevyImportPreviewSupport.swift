#if DEBUG
import Foundation
import PulseServices
import SwiftUI

/// Un extrait inventé au format de l'export Hevy, pour les aperçus : deux séances, un nom inconnu et du cardio.
@MainActor
enum HevyImportPreviewSupport {
    // swiftlint:disable line_length
    static let csv = """
    "title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
    "Push","26 oct. 2026, 07:00","26 oct. 2026, 08:06","","Développé Couché (Barre)",,"",0,"normal",60,12,,,7.5
    "Push","26 oct. 2026, 07:00","26 oct. 2026, 08:06","","Écarté (Machine)",,"",0,"normal",40,10,,,
    "Push","26 oct. 2026, 07:00","26 oct. 2026, 08:06","","Curl Inventé Haltère",,"",0,"normal",12,10,,,
    "Push","26 oct. 2026, 07:00","26 oct. 2026, 08:06","","Tapis de Course",,"",0,"normal",,,1.4,600,
    "Pull","27 oct. 2026, 07:17","27 oct. 2026, 07:59","","Extension Triceps Poulie Haute",,"",0,"failure",30.5,3,,,9.5
    "Pull","27 oct. 2026, 07:17","27 oct. 2026, 07:59","","Curl Inventé Haltère",,"",0,"normal",14,8,,,
    """
    // swiftlint:enable line_length

    static func model() -> HevyImportModel {
        let environment = TrainPreviewSupport.environment(
            profiles: InMemoryProfileRepository(), programs: InMemoryProgramRepository(),
            recovery: InMemoryRecoveryRepository(calendar: TrainPreviewSupport.calendar),
            now: TrainPreviewSupport.date(day: 2, hour: 9))
        return HevyImportModel(environment: environment)
    }
}

/// Affiche le parcours à l'étape voulue, sur l'extrait en mémoire : lu (résumé ou correspondance) ou importé (bilan).
private struct HevyImportPreviewHost: View {
    enum Stage { case intro, summary, mapping, done, failed }

    let stage: Stage
    @State private var model = HevyImportPreviewSupport.model()

    var body: some View {
        NavigationStack {
            HevyImportFlow(model: model)
        }
        .task {
            switch stage {
            case .intro: break
            case .summary: await model.read(Data(HevyImportPreviewSupport.csv.utf8))
            case .mapping:
                await model.read(Data(HevyImportPreviewSupport.csv.utf8))
                model.showMapping()
            case .done:
                await model.read(Data(HevyImportPreviewSupport.csv.utf8))
                await model.start()
            case .failed: await model.read(Data("a,b\n1,2\n".utf8))
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Choix du fichier") {
    HevyImportPreviewHost(stage: .intro)
}

#Preview("Résumé") {
    HevyImportPreviewHost(stage: .summary)
}

#Preview("Correspondance") {
    HevyImportPreviewHost(stage: .mapping)
}

#Preview("Bilan") {
    HevyImportPreviewHost(stage: .done)
}

#Preview("Fichier refusé") {
    HevyImportPreviewHost(stage: .failed)
}
#endif
