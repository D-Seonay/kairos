import Foundation
import PulseContent
import PulseDomain
import Testing

private final class Marker {}

@Test func loadFailsOnMissingResource() {
    #expect(throws: ContentError.missingResource("exercises.json")) {
        try ContentLibrary.load(from: Bundle(for: Marker.self))
    }
}

@Test func bundledLibraryLoads() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    #expect(lib.contentVersion == "1.2.0")
    #expect(lib.exercise(id: "does-not-exist") == nil)
    #expect(lib.programTemplate(id: "does-not-exist") == nil)
}

@Test func libraryLookupsAndActiveFilter() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[0].retired = true
    let lib = Fixtures.library(exercises: exercises)
    #expect(lib.exercises.count == 4)
    #expect(lib.activeExercises.map(\.id) == ["p-2", "p-3", "p-4"])
    #expect(lib.exercise(id: "p-1")?.retired == true)
}

@Test func programsKeepTheirSubdirectory() {
    #expect(ContentLibrary.resourceBundle.url(forResource: "ppl-3", withExtension: "json", subdirectory: "Programs") != nil)
}

@Test func hevyNamesAreFoldedAtInit() {
    let catalog = ExerciseCatalog(schemaVersion: 1, contentVersion: "1.0.0", exercises: Fixtures.fourExercises(pattern: .squat))
    let lib = ContentLibrary(catalog: catalog, templates: [], hevyNames: ["Écarté (Machine)": "p-1"])
    #expect(lib.hevyNames == ["ecarte machine": "p-1"])
    #expect(lib.exerciseID(forHevyName: "  ECARTE   (machine) ") == "p-1")
    #expect(lib.exerciseID(forHevyName: "Écarté") == nil)
    #expect(Fixtures.library(exercises: []).hevyNames.isEmpty)
}
