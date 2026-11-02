import Foundation
import PulseContent
import PulseDomain
import Testing

@Test func hevyNamesResolveWhateverTheCaseAndAccents() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    #expect(lib.exerciseID(forHevyName: "Écarté (Machine)") == "pec-deck-machine")
    #expect(lib.exerciseID(forHevyName: "ecarte (machine)") == "pec-deck-machine")
    #expect(lib.exerciseID(forHevyName: "Dips Torse (Assisté)") == "assisted-dips-machine")
    #expect(lib.exerciseID(forHevyName: "Pull (machine)") == nil)
}

@Test func everyHevyNameOfTheSpecResolves() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    let table: [String: String] = [
        "Développé Couché (Barre)": "bench-press-barbell", "Développé Couché (Haltère)": "bench-press-dumbbell",
        "Développé Couché Incliné (Haltère)": "incline-bench-press-dumbbell", "Chest Press Convergent (Machine)": "chest-press-machine",
        "Écarté (Machine)": "pec-deck-machine", "Butterfly (Pec Deck)": "pec-deck-machine", "Écartés Poulie": "cable-crossover",
        "Extension Triceps Poulie Haute": "triceps-pushdown-cable",
        "Overhead Triceps Extension (Cable)": "overhead-triceps-extension-cable", "Dips Triceps": "dips",
        "Avant Bras Poulie Barre Droite": "wrist-curl-cable", "Élévation Latérale (Machine)": "lateral-raise-machine",
        "Élévation Latérale (Haltère)": "lateral-raise-dumbbell", "Oiseau (Machine)": "reverse-pec-deck-machine",
        "Presse Épaules Assis (Machine)": "shoulder-press-machine", "Tirage Haut Machine Convergente": "lat-pulldown-machine",
        "Tirage Poitrine (Poulie)": "lat-pulldown-cable", "Tractions": "pull-up",
        "Tirage bas iso-latéral": "seated-row-machine-iso-lateral", "Seated Cable Row - V Grip (Cable)": "seated-cable-row",
        "Tirage assis à la poulie - prise en V (poulie)": "seated-cable-row", "Rowing Penché (Barre)": "barbell-row",
        "Curl Pupitre (Machine)": "preacher-curl-machine", "Curl Marteau (Haltère)": "hammer-curl-dumbbell",
        "Crunch (Machine)": "crunch-machine", "Presse à Cuisses": "leg-press-machine", "Hack Squat (Machine)": "hack-squat-machine",
        "Extension Jambes": "leg-extension-machine", "Leg Curl Allongé (Machine)": "lying-leg-curl-machine",
        "Leg Curl Assis": "seated-leg-curl-machine", "Abduction Hanche": "hip-abduction-machine",
        "Adduction Hanche": "hip-adduction-machine", "Extension Mollets Assis": "seated-calf-raise-machine",
        "Extension Mollets (Machine)": "standing-calf-raise-machine", "Soulevé de Terre (Barre)": "deadlift-barbell",
        "Dips Torse (Assisté)": "assisted-dips-machine", "Dips Pectoraux (Assisté)": "assisted-dips-machine",
        "Dips Triceps (Assisté)": "assisted-dips-machine", "Machine Dips Assis": "assisted-dips-machine",
        "Tirage Poitrine - Prise Serrée (Poulie)": "close-grip-lat-pulldown-cable", "Curl Biceps (Haltère)": "dumbbell-curl",
        "Extension Triceps Corde": "rope-pushdown-cable", "Extension Triceps (Machine)": "triceps-extension-machine",
        "Développé Couché Décliné (Machine)": "decline-chest-press-machine", "Extension Dos (Machine)": "back-extension-machine",
        "Extension Dos (Hyperextension Lestée)": "hyperextension", "Curl Poignets Paumes vers le Haut Assis": "seated-wrist-curl-dumbbell"
    ]
    for (name, id) in table { #expect(lib.exerciseID(forHevyName: name) == id, Comment(rawValue: name)) }
}

@Test func bundledHevyTableTargetsActiveExercises() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    #expect(lib.hevyNames.count >= 43)
    #expect(ContentValidator.issues(in: lib).filter { $0.rule == .hevyNames }.isEmpty)
    for (name, id) in lib.hevyNames {
        #expect(name == SearchText.fold(name), Comment(rawValue: name))
        #expect(lib.exercise(id: id)?.retired == false, Comment(rawValue: id))
    }
}

@Test func validatorRejectsHevyNamesPointingToUnknownOrRetiredExercises() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[0].retired = true
    let catalog = ExerciseCatalog(schemaVersion: 1, contentVersion: "1.0.0", exercises: exercises)
    let lib = ContentLibrary(catalog: catalog, templates: [],
                             hevyNames: ["Squat": "p-2", "Ghost": "ghost", "Old": "p-1"])
    let issues = ContentValidator.issues(in: lib, ignoring: [.exerciseCount, .patternPopulation])
    #expect(issues.map(\.rule) == [.hevyNames, .hevyNames])
    #expect(issues.map(\.subject) == ["ghost", "old"])
}
