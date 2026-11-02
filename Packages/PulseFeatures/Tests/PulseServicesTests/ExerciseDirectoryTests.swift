import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

extension Date {
    static let t0 = TestClock.date("2026-11-02T08:00")
}

struct ExerciseDirectoryTests {
    static let shrug = UserExercise(
        name: "Shrug (Haltère)", primaryMuscle: .traps, secondaryMuscles: [], equipment: .dumbbell, pattern: .shoulderIsolation,
        region: .upper, isUnilateral: false, defaultIncrementKg: 2.5, defaultRestSeconds: 60, createdAt: .t0, updatedAt: .t0)

    @Test func directoryResolvesContentAndUserExercises() {
        let directory = ExerciseDirectory(library: .bundled, userExercises: [Self.shrug])
        #expect(directory.info(.content(id: "pec-deck-machine"))?.name == "Écarté à la machine")
        #expect(directory.info(.user(id: Self.shrug.id))?.group == .back)
        #expect(directory.active.count == 94)
        #expect(directory.loadKind(of: .content(id: "assisted-dips-machine")) == .assisted)
    }

    @Test func contentInfoCarriesTheCatalogEntry() throws {
        let directory = ExerciseDirectory(library: .bundled, userExercises: [])
        let info = try #require(directory.info(.content(id: "triceps-pushdown-cable")))
        let exercise = try #require(ContentLibrary.bundled.exercise(id: "triceps-pushdown-cable"))
        #expect(info.content == exercise)
        #expect(info.englishName == exercise.name.en)
        #expect(info.id == info.reference && info.isActive)
        #expect(info.defaultIncrementKg == exercise.defaultIncrementKg && info.tracksDuration == exercise.tracksDuration)
    }

    @Test func userInfoCopiesTheCustomExerciseWithoutContent() throws {
        var timed = Self.shrug
        timed.tracksDuration = true
        timed.loadKind = .bodyweight
        timed.isCompound = true
        let info = try #require(ExerciseDirectory(library: .bundled, userExercises: [timed]).info(.user(id: timed.id)))
        #expect(info.content == nil && info.englishName == nil)
        #expect(info.primaryMuscles == [.traps] && info.equipment == .dumbbell && info.region == .upper)
        #expect(info.tracksDuration && info.isCompound && info.loadKind == .bodyweight)
        #expect(info.defaultRestSeconds == 60 && info.isActive)
    }

    @Test func archivedAndRetiredExercisesStayResolvableButInactive() throws {
        var archived = Self.shrug
        archived.isArchived = true
        var retired = try #require(ContentLibrary.bundled.exercise(id: "pec-deck-machine"))
        retired.retired = true
        let catalog = ExerciseCatalog(schemaVersion: 1, contentVersion: "test", exercises: [retired])
        let directory = ExerciseDirectory(library: ContentLibrary(catalog: catalog, templates: []), userExercises: [archived])
        #expect(directory.info(.user(id: archived.id))?.isActive == false)
        #expect(directory.info(.content(id: retired.id))?.isActive == false)
        #expect(directory.active.isEmpty)
    }

    @Test func nameAndLoadKindFallBackForUnknownReferences() {
        let directory = ExerciseDirectory(library: .bundled, userExercises: [Self.shrug])
        let unknown = ExerciseReference.user(id: UUID())
        #expect(directory.info(unknown) == nil)
        #expect(directory.name(of: unknown, fallback: "Ancien exercice") == "Ancien exercice")
        #expect(directory.name(of: .user(id: Self.shrug.id), fallback: "x") == "Shrug (Haltère)")
        #expect(directory.name(of: .content(id: "pec-deck-machine"), fallback: "x") == "Écarté à la machine")
        #expect(directory.loadKind(of: unknown) == .external)
        #expect(directory.loadKind(of: .content(id: "inconnu")) == .external)
    }
}
