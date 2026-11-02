import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func programRoundTripsThroughStoredModel() throws {
    let program = Sample.program()
    let stored = StoredProgram(program)
    #expect(stored.toDomain() == program)
}

@Test func applyRemovesMissingDaysLogically() throws {
    let container = try TestContainer.make()
    let context = ModelContext(container)
    var program = Sample.program(days: 2)
    let stored = StoredProgram(program)
    context.insert(stored)
    try context.save()
    program.days.removeLast()
    program.days[0].exercises.removeLast()
    program.days[0].name = "Jour renommé"
    stored.apply(program)
    try context.save()
    #expect(stored.toDomain() == program)
    let days = try context.fetch(FetchDescriptor<StoredRoutineDay>())
    #expect(days.count == 2 && days.filter { $0.deletedAt != nil }.count == 1)
    let exercises = try context.fetch(FetchDescriptor<StoredRoutineExercise>())
    #expect(exercises.count == 6 && exercises.filter { $0.deletedAt == nil }.count == 2)
}

@Test func sessionRoundTripsWithSetsAndAdjustments() throws {
    let session = Sample.session()
    let stored = StoredWorkoutSession(session)
    #expect(stored.toDomain() == session)
    var fewer = session
    fewer.sets.removeFirst()
    fewer.sets[0].actualReps = 12
    stored.apply(fewer)
    #expect(stored.toDomain() == fewer)
    #expect(stored.sets?.count == 9)
}

@Test func profileScheduledDayAndUserExerciseRoundTrip() throws {
    var profile = UserProfile(createdAt: Fixed.t1, updatedAt: Fixed.t2)
    #expect(StoredProfile(profile).toDomain() == profile)
    profile.birthDate = Fixed.t0
    profile.heightCm = 180
    profile.restWeekdays = [.sunday]
    profile.painAreas = [.knees]
    profile.antiInterferenceRulesDisabled = [.fullRestDay]
    profile.morningScoreDeadlineMinutes = 540
    profile.onboardingCompletedAt = Fixed.t0
    profile.activeProgramID = UUID()
    profile.deloadDeclinedAt = Fixed.t0
    #expect(StoredProfile(profile).toDomain() == profile)

    let day = Sample.scheduledDay()
    #expect(StoredScheduledDay(day).toDomain() == day)
    var bare = day
    bare.programID = nil
    bare.routineDayID = nil
    bare.movedFromDate = nil
    bare.moveReason = nil
    bare.moveReasonText = nil
    #expect(StoredScheduledDay(bare).toDomain() == bare)

    let exercise = Sample.userExercise()
    #expect(StoredUserExercise(exercise).toDomain() == exercise)
}

@Test func m4TrainingFieldsRoundTripThroughStoredModels() {
    var program = Sample.program()
    program.days[0].exercises[0].setTargets = [SetTarget(repsMin: 6, repsMax: 8), SetTarget(repsMin: 10, repsMax: 12)]
    #expect(StoredProgram(program).toDomain() == program)

    var session = Sample.session()
    session.source = .hevy
    session.exerciseNotes = [ExerciseNote(exercise: .content(id: "plank"), text: "Gainage solide"),
                             ExerciseNote(exercise: .user(id: UUID()), text: "Siège cran 4")]
    session.sets[1].durationSeconds = 45
    #expect(StoredWorkoutSession(session).toDomain() == session)

    var exercise = Sample.userExercise()
    exercise.loadKind = .assisted
    exercise.isCompound = true
    exercise.tracksDuration = true
    #expect(StoredUserExercise(exercise).toDomain() == exercise)
}

@Test func exerciseSettingsRoundTripFilledThenEmpty() {
    var settings = Sample.exerciseSettings(exercise: .user(id: UUID()))
    #expect(StoredExerciseSettings(settings).toDomain() == settings)
    settings.exercise = .content(id: "squat-barbell")
    settings.incrementKg = nil
    settings.warmupSetCount = nil
    #expect(StoredExerciseSettings(settings).toDomain() == settings)
    let stored = StoredExerciseSettings(Sample.exerciseSettings())
    stored.apply(settings)
    #expect(stored.toDomain().exercise == settings.exercise && stored.incrementKg == nil && stored.warmupSetCount == nil)
}

/// Les dates des jours, exercices de routine et séries n'existent qu'en stockage : elles suivent le `updatedAt` du parent.
@Test func childDatesFollowTheParentUpdatedAt() throws {
    var program = Sample.program(days: 1)
    let storedProgram = StoredProgram(program)
    let day = try #require(storedProgram.days?.first)
    #expect(day.createdAt == Fixed.t2 && day.updatedAt == Fixed.t2)
    #expect(day.exercises?.allSatisfy { $0.createdAt == Fixed.t2 && $0.updatedAt == Fixed.t2 } == true)
    let later = Fixed.t2.addingTimeInterval(60)
    program.updatedAt = later
    program.days[0].exercises.append(Sample.routineExercise(order: 3))
    storedProgram.apply(program)
    #expect(day.createdAt == Fixed.t2 && day.updatedAt == later)
    let exercises = day.exercises ?? []
    #expect(exercises.count == 4 && exercises.allSatisfy { $0.updatedAt == later })
    #expect(exercises.filter { $0.createdAt == later }.count == 1)

    var session = Sample.session(sets: 2)
    let storedSession = StoredWorkoutSession(session)
    #expect(storedSession.sets?.allSatisfy { $0.createdAt == Fixed.t2 && $0.updatedAt == Fixed.t2 } == true)
    session.updatedAt = later
    session.sets.append(Sample.set(order: 3))
    storedSession.apply(session)
    let sets = storedSession.sets ?? []
    #expect(sets.count == 3 && sets.allSatisfy { $0.updatedAt == later })
    #expect(sets.filter { $0.createdAt == later }.count == 1)
}
