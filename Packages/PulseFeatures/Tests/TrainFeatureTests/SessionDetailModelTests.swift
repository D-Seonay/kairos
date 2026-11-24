import Foundation
import PhotosFeature
import PulseDesignSystem
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

private let bench = ExerciseReference.content(id: "bench-press-barbell")
private let fly = ExerciseReference.content(id: "dumbbell-fly")

/// Une séance Hevy « Push » : développé couché (échauffement, deux séries de travail), puis des écartés ; avec une note.
@MainActor
private func hevyPush(_ fixture: TrainFixture, status: SessionStatus = .completed) async throws -> WorkoutSession {
    let date = TrainClock.date(month: 10, day: 12, hour: 18)
    func set(_ order: Int, _ exercise: ExerciseReference, _ weight: Double, _ reps: Int, type: SetType = .working,
             rpe: Double? = nil) -> WorkoutSet {
        WorkoutSet(order: order, exercise: exercise, exerciseName: "Exercice", setType: type, actualWeightKg: weight,
                   actualReps: reps, rpe: rpe, completedAt: date)
    }
    let session = WorkoutSession(
        startedAt: date, endedAt: date.addingTimeInterval(3_600), kind: .strength, source: .hevy, status: status, title: "Push",
        note: "Bonne forme.", exerciseNotes: [ExerciseNote(exercise: bench, text: "Pause en bas")],
        sets: [set(0, bench, 40, 10, type: .warmup), set(1, bench, 80, 5, rpe: 8), set(2, bench, 82.5, 4, rpe: 9.5),
               set(3, fly, 15, 12)],
        createdAt: date, updatedAt: date)
    try await fixture.environment.workouts.save(session)
    return session
}

@MainActor @Test func detailGroupsSetsByExerciseInOrder() async throws {
    let fixture = TrainFixture()
    // Une séance plus ancienne : un record n'existe qu'au-dessus d'un passé.
    try await fixture.log(on: TrainClock.date(month: 10, day: 5, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 5)])
    let session = try await hevyPush(fixture)
    _ = try await fixture.environment.records.recomputeAll()
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    #expect(model.session?.title == "Push")
    #expect(model.blocks.map(\.exercise) == [bench, fly])
    let first = try #require(model.blocks.first)
    #expect(first.note == "Pause en bas")
    #expect(first.sets.map(\.text) == ["40 × 10", "80 × 5", "82,5 × 4"])
    #expect(first.sets.map(\.type) == [.warmup, .working, .working])
    #expect(first.sets.map(\.rpe) == [nil, 8, 9.5])
    #expect(first.sets.contains { $0.isRecord })
    #expect(model.blocks[1].note == nil)
    #expect(model.blocks[1].sets.map(\.text) == ["15 × 12"])
}

@MainActor @Test func detailFormatsSetsWithoutLoadOrHeldForATime() async throws {
    let fixture = TrainFixture()
    let date = TrainClock.date(month: 10, day: 12, hour: 18)
    let sets = [WorkoutSet(order: 0, exercise: .content(id: "pull-up"), exerciseName: "Tractions", setType: .working,
                           actualReps: 8, completedAt: date),
                WorkoutSet(order: 1, exercise: .content(id: "plank"), exerciseName: "Gainage", setType: .working,
                           durationSeconds: 45, completedAt: date)]
    let session = WorkoutSession(startedAt: date, endedAt: date, kind: .strength, source: .pulse, status: .completed,
                                 title: "Haut du corps", sets: sets, createdAt: date, updatedAt: date)
    try await fixture.environment.workouts.save(session)
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    #expect(model.blocks.map { $0.sets.map(\.text) } == [["8"], ["45 s"]])
}

@MainActor @Test func detailMuscleMapCountsWorkingSetsOnly() async throws {
    let fixture = TrainFixture()
    let session = try await hevyPush(fixture)
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    let directory = ExerciseDirectory(library: fixture.environment.library, userExercises: [])
    var weights: [Muscle: Double] = [:]
    for (exercise, sets) in [(bench, 2.0), (fly, 1.0)] {
        let info = try #require(directory.info(exercise))
        for muscle in info.primaryMuscles { weights[muscle, default: 0] += sets }
        for muscle in info.secondaryMuscles where !info.primaryMuscles.contains(muscle) { weights[muscle, default: 0] += sets / 2 }
    }
    #expect(!model.muscleLevels.isEmpty)
    #expect(model.muscleLevels == MuscleIntensity.levels(weights: weights))
}

@MainActor @Test func detailOfAMissingSessionIsMissing() async {
    let model = SessionDetailModel(environment: TrainFixture().environment, sessionID: UUID())
    await model.load()
    #expect(model.isMissing)
    #expect(model.session == nil)
    #expect(model.hasLoaded)
}

@MainActor @Test func savingAnImportedSessionAsRoutineAddsItToTheActiveProgram() async throws {
    let fixture = TrainFixture()
    let now = fixture.now
    let existing = ProgramEditor.addDay(named: "Pull", exercises: [], to: ProgramEditor.emptyProgram(name: "PPL", now: now), now: now)
    try await fixture.activate(existing.program)
    let session = try await hevyPush(fixture)
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    let (programID, dayID) = try await model.saveAsRoutine()
    #expect(programID == existing.program.id)
    let program = try #require(try await fixture.programs.program(id: programID))
    #expect(program.days.map(\.name) == ["Pull", "Push"])
    let day = try #require(program.days.first { $0.id == dayID })
    #expect(day.exercises.map(\.exercise) == [bench, fly])
    #expect(day.exercises.map(\.sets) == [2, 1])
    #expect(try await fixture.profiles.load()?.activeProgramID == programID)
}

@MainActor @Test func savingASessionAsRoutineWithoutAProgramCreatesAnActiveOne() async throws {
    let fixture = TrainFixture()
    try await fixture.saveProfile()
    let session = try await hevyPush(fixture)
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    let (programID, dayID) = try await model.saveAsRoutine()
    let program = try #require(try await fixture.programs.program(id: programID))
    #expect(program.name == "Mon programme")
    #expect(program.days.map(\.id) == [dayID])
    #expect(try await fixture.profiles.load()?.activeProgramID == programID)
}

@MainActor @Test func savingASessionWithoutWorkingSetsAsRoutineFails() async throws {
    let fixture = TrainFixture()
    try await fixture.saveProfile()
    let session = try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18),
                                        sets: [LoggedSet(weightKg: 40, reps: 10, type: .warmup)])
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    #expect(!model.canSaveAsRoutine)
    await #expect(throws: SessionDetailError.nothingToSave) { try await model.saveAsRoutine() }
    #expect(try await fixture.programs.programs(includeArchived: true).isEmpty)
}

@MainActor @Test func deletingASessionRecomputesRecords() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 5, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 5)])
    let middle = try await fixture.log(on: TrainClock.date(month: 10, day: 8, hour: 18), sets: [LoggedSet(weightKg: 70, reps: 5)])
    let best = try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 90, reps: 5)])
    _ = try await fixture.environment.records.recomputeAll()
    let before = try await fixture.environment.personalRecords.records(for: bench).map(\.value).max()
    let model = SessionDetailModel(environment: fixture.environment, sessionID: best.id)
    await model.load()
    try await model.delete()
    #expect(try await fixture.environment.workouts.session(id: best.id) == nil)
    #expect(model.isMissing)
    let after = try await fixture.environment.personalRecords.records(for: bench).map(\.value).max()
    let (afterValue, beforeValue) = (try #require(after), try #require(before))
    #expect(afterValue < beforeValue)
    let kept = try #require(try await fixture.environment.workouts.session(id: middle.id))
    #expect(kept.sets.allSatisfy { $0.isPersonalRecord })
}

@MainActor @Test func deletingASessionDeletesItsAppleHealthWorkout() async throws {
    let writer = StubWorkoutHealthWriter()
    let fixture = TrainFixture(healthWriter: writer)
    var session = try await fixture.log(on: TrainClock.date(day: 1, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)])
    let workoutID = UUID()
    session.healthKitUUID = workoutID.uuidString
    try await fixture.environment.workouts.save(session)
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    try await model.delete()
    #expect(await writer.deleted == [workoutID])
}

@MainActor @Test func correctionSavesSetsNoteAndRecomputesRecords() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 5, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 5)])
    let session = try await hevyPush(fixture)
    _ = try await fixture.environment.records.recomputeAll()
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    #expect(model.correctableBlocks.map(\.setIDs.count) == [2, 1])

    var correction = try #require(model.correction())
    correction.sets[1].weightKg = 90
    correction.removedSetIDs = [correction.sets[2].id]
    correction.note = "Corrigée"
    try await model.save(correction)

    let saved = try #require(try await fixture.environment.workouts.session(id: session.id))
    #expect(saved.sets.count == 3 && saved.note == "Corrigée")
    #expect(saved.sets.first { $0.order == 2 }?.actualWeightKg == 90)
    #expect(saved.sets.first { $0.order == 2 }?.isPersonalRecord == true)
    #expect(saved.tonnageKg == 80 * 5 + 90 * 4)
    #expect(model.session?.note == "Corrigée")
}

@MainActor @Test func detailSaysSetsSummaryAndMusclesInWords() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 5, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 5)])
    let session = try await hevyPush(fixture)
    _ = try await fixture.environment.records.recomputeAll()
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    let first = try #require(model.blocks.first)
    #expect(first.sets.map(\.spokenText) == ["40 kilos, 10 répétitions", "80 kilos, 5 répétitions", "82,5 kilos, 4 répétitions"])
    #expect(model.summaryText.contains(" · ") && model.summaryText.contains("kg"))
    #expect(!model.summarySpokenText.contains(" · ") && !model.summarySpokenText.contains("kg"))
    #expect(model.summarySpokenText.hasPrefix("1 heure, 3 séries") || model.summarySpokenText.hasPrefix("1 heure 0"))
    #expect(model.headerSpokenText.contains("importée de Hevy") && model.headerSpokenText.hasSuffix(model.summarySpokenText))
    #expect(model.musclesSpokenText.hasPrefix("Muscles travaillés par la séance. "))
    #expect(model.musclesSpokenText.contains("Pectoraux, intensité "))
}

@MainActor @Test func detailSaysOneWorkingSetInTheSingular() async throws {
    let fixture = TrainFixture()
    let session = try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 80, reps: 5)])
    let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
    await model.load()
    #expect(model.summaryText.contains("1 série ·") && model.summarySpokenText.contains("1 série,"))
}

// MARK: - Photos

@MainActor @Test func sessionDetailOffersPhotosForPulseAndHevy() async throws {
    let fixture = TrainFixture(withPhotos: true)
    let date = TrainClock.date(month: 10, day: 12, hour: 18)
    let pulse = try await fixture.log(on: date, sets: [LoggedSet(weightKg: 60, reps: 5)], source: .pulse)
    let hevy = try await fixture.log(on: date.addingTimeInterval(86_400), sets: [LoggedSet(weightKg: 60, reps: 5)], source: .hevy)
    for session in [pulse, hevy] {
        let model = SessionDetailModel(environment: fixture.environment, sessionID: session.id)
        #expect(model.photos == nil)
        // Une photo déjà prise sous l'identifiant de la séance se relit par le modèle de la section.
        _ = try await fixture.photos.add(TestImages.jpeg(), to: session.id)
        await model.load()
        let photos = try #require(model.photos)
        await photos.load()
        #expect(photos.photos.count == 1)
    }

    let withoutService = TrainFixture()
    let bare = try await withoutService.log(on: date, sets: [LoggedSet(weightKg: 60, reps: 5)])
    let model = SessionDetailModel(environment: withoutService.environment, sessionID: bare.id)
    await model.load()
    #expect(model.session != nil)
    #expect(model.photos == nil)
}

@MainActor @Test func sessionDetailHidesPhotosForAppleHealthAndMissingSessions() async throws {
    let fixture = TrainFixture(withPhotos: true)
    let health = try await fixture.log(on: TrainClock.date(day: 1, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 5)],
                                       source: .appleHealth)
    let model = SessionDetailModel(environment: fixture.environment, sessionID: health.id)
    await model.load()
    #expect(model.session != nil)
    #expect(model.photos == nil)

    let missing = SessionDetailModel(environment: fixture.environment, sessionID: UUID())
    await missing.load()
    #expect(missing.isMissing)
    #expect(missing.photos == nil)
}
