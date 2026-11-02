import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

@MainActor @Test func libraryFiltersAndPicksInTapOrder() async {
    let fixture = TrainFixture()
    let model = LibraryModel(environment: fixture.environment, mode: .pick(multiple: true))
    await model.load()
    model.query = "ecarte"
    #expect(!model.results.isEmpty)
    #expect(model.results.allSatisfy { SearchText.fold($0.name).contains("ecarte") })
    #expect(model.results.map(\.reference).contains(.content(id: "pec-deck-machine")))
    model.toggle(.content(id: "pec-deck-machine"))
    model.toggle(.content(id: "cable-crossover"))
    #expect(model.confirm() == [.content(id: "pec-deck-machine"), .content(id: "cable-crossover")])
    #expect(model.selection == [.content(id: "pec-deck-machine"), .content(id: "cable-crossover")])
}

@MainActor @Test func libraryFiltersByGroupAndEquipment() async {
    let model = LibraryModel(environment: TrainFixture().environment, mode: .browse)
    await model.load()
    #expect(model.results.count == ContentLibrary.bundled.activeExercises.count)
    model.group = .chest
    model.equipment = .dumbbell
    #expect(!model.results.isEmpty)
    #expect(model.results.allSatisfy { $0.group == .chest && $0.equipment == .dumbbell })
    model.query = "zzz introuvable"
    #expect(model.results.isEmpty)
}

@MainActor @Test func libraryListsRecentExercisesFirst() async throws {
    let fixture = TrainFixture()
    try await fixture.log(.content(id: "plank"), on: TrainClock.date(day: 1, hour: 18), sets: [LoggedSet(weightKg: 0, reps: 1)])
    try await fixture.log(.content(id: "barbell-curl"), on: TrainClock.date(month: 9, day: 1, hour: 18),
                          sets: [LoggedSet(weightKg: 30, reps: 10)])
    let model = LibraryModel(environment: fixture.environment, mode: .browse)
    await model.load()
    #expect(model.results.first?.reference == .content(id: "plank"))
    #expect(model.isRecent(.content(id: "plank")))
    #expect(!model.isRecent(.content(id: "barbell-curl")))
}

@MainActor @Test func libraryOffersUserExercisesButNotArchivedOnes() async throws {
    let fixture = TrainFixture()
    let kept = userExercise(name: "Zercher squat")
    let archived = userExercise(name: "Rowing archivé", isArchived: true)
    try await fixture.store(kept)
    try await fixture.store(archived)
    let model = LibraryModel(environment: fixture.environment, mode: .browse)
    await model.load()
    #expect(model.results.map(\.reference).contains(.user(id: kept.id)))
    #expect(!model.results.map(\.reference).contains(.user(id: archived.id)))
}

@MainActor @Test func libraryShowsTheCurrentEstimatedOneRepMax() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 70, reps: 5)])
    try await fixture.log(on: TrainClock.date(month: 10, day: 26, hour: 18), sets: [LoggedSet(weightKg: 72.5, reps: 5)])
    _ = try await fixture.environment.records.recomputeAll()
    let model = LibraryModel(environment: fixture.environment, mode: .browse)
    await model.load()
    #expect(model.oneRepMax(for: .content(id: "bench-press-barbell")).map { ($0 * 100).rounded() / 100 } == 81.56)
    #expect(model.oneRepMax(for: .content(id: "plank")) == nil)
}

@MainActor @Test func libraryPickModesDecideWhatATouchDoes() async {
    let fixture = TrainFixture()
    let bench = ExerciseReference.content(id: "bench-press-barbell")
    let plank = ExerciseReference.content(id: "plank")

    let browse = LibraryModel(environment: fixture.environment, mode: .browse)
    browse.toggle(bench)
    #expect(browse.confirm().isEmpty)

    let multiple = LibraryModel(environment: fixture.environment, mode: .pick(multiple: true))
    multiple.toggle(bench)
    multiple.toggle(plank)
    multiple.toggle(bench)
    #expect(multiple.confirm() == [plank])

    let single = LibraryModel(environment: fixture.environment, mode: .pick(multiple: false))
    single.toggle(bench)
    single.toggle(plank)
    #expect(single.confirm() == [plank])
}

/// Un exercice perso de poussée, prêt à enregistrer.
func userExercise(name: String, isArchived: Bool = false) -> UserExercise {
    let date = TrainClock.date(day: 1, hour: 9)
    return UserExercise(name: name, primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .barbell, pattern: .squat,
                        region: .lower, isUnilateral: false, defaultIncrementKg: 5, defaultRestSeconds: 120,
                        isCompound: true, isArchived: isArchived, createdAt: date, updatedAt: date)
}
