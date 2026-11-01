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
