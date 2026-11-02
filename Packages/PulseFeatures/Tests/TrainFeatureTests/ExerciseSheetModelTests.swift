import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

private let bench = ExerciseReference.content(id: "bench-press-barbell")

/// Trois séances de développé couché : 2 oct 60×10 (1RM 80), 12 oct 70×5 (78,75), 26 oct 72,5×5 (81,56), records recalculés.
@MainActor
private func benchFixture() async throws -> TrainFixture {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 2, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 10)])
    try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 70, reps: 5)])
    try await fixture.log(on: TrainClock.date(month: 10, day: 26, hour: 18), sets: [LoggedSet(weightKg: 72.5, reps: 5)])
    _ = try await fixture.environment.records.recomputeAll()
    return fixture
}

@MainActor @Test func sheetShowsProgressionFromHistory() async throws {
    let fixture = try await benchFixture()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    #expect(model.currentOneRepMax.map { ($0 * 10).rounded() / 10 } == 81.6)
    #expect(model.chart.count == 3)
    #expect(model.recentSessions.first?.setsText == "72,5 × 5")
    #expect(model.alternatives.map(\.reference) == [.content(id: "chest-press-machine"), .content(id: "bench-press-dumbbell"),
                                                    .content(id: "incline-chest-press-machine")])
}

@MainActor @Test func sheetComparesTheOneRepMaxWithThirtyDaysAgo() async throws {
    let fixture = try await benchFixture()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    // Le 2 oct est antérieur au 3 oct (30 jours avant le 2 nov) : 81,5625 − 80.
    #expect(model.oneRepMaxChange30Days.map { ($0 * 100).rounded() / 100 } == 1.56)
    #expect(model.bestSet?.weightKg == 72.5)
    #expect(model.bestSet?.reps == 5)
    #expect(model.bestSet?.date == TrainClock.date(month: 10, day: 26, hour: 18))
    #expect(model.chart.map(\.date) == [TrainClock.date(month: 10, day: 2, hour: 18), TrainClock.date(month: 10, day: 12, hour: 18),
                                        TrainClock.date(month: 10, day: 26, hour: 18)])
    #expect(model.chart.map { ($0.value * 100).rounded() / 100 } == [80, 78.75, 81.56])
}

@MainActor @Test func sheetWithoutThirtyDayHistoryHasNoChange() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 26, hour: 18), sets: [LoggedSet(weightKg: 72.5, reps: 5)])
    _ = try await fixture.environment.records.recomputeAll()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    #expect(model.currentOneRepMax != nil)
    #expect(model.oneRepMaxChange30Days == nil)
}

@MainActor @Test func sheetChartKeepsTheLastNinetyDaysOnly() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 6, day: 1, hour: 18), sets: [LoggedSet(weightKg: 50, reps: 10)])
    try await fixture.log(on: TrainClock.date(month: 10, day: 26, hour: 18), sets: [LoggedSet(weightKg: 72.5, reps: 5)])
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    #expect(model.chart.count == 1)
    #expect(model.recentSessions.count == 2)
}

@MainActor @Test func sheetSummarisesEachSessionWithoutWarmups() async throws {
    let fixture = TrainFixture()
    let session = try await fixture.log(on: TrainClock.date(month: 10, day: 26, hour: 18), sets: [
        LoggedSet(weightKg: 40, reps: 10, type: .warmup),
        LoggedSet(weightKg: 60, reps: 8, rpe: 7),
        LoggedSet(weightKg: 70, reps: 5, rpe: 8.5),
        LoggedSet(weightKg: 70, reps: 5, rpe: 9)
    ])
    _ = try await fixture.environment.records.recomputeAll()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    let line = try #require(model.recentSessions.first)
    #expect(line.id == session.id)
    #expect(line.setsText == "60 × 8 · 70 × 5 · 5")
    #expect(line.maxRPE == 9)
    #expect(line.tonnageKg == 60 * 8 + 70 * 5 + 70 * 5)
    #expect(!line.hasRecord)
}

@MainActor @Test func sheetFlagsTheSessionsWhereARecordFell() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 70, reps: 5)])
    try await fixture.log(on: TrainClock.date(month: 10, day: 26, hour: 18), sets: [LoggedSet(weightKg: 72.5, reps: 5)])
    _ = try await fixture.environment.records.recomputeAll()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    #expect(model.recentSessions.map(\.hasRecord) == [true, false])
}

@MainActor @Test func sheetKeepsTheTenLatestSessions() async throws {
    let fixture = TrainFixture()
    for day in 1...12 {
        try await fixture.log(on: TrainClock.date(month: 10, day: day, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)])
    }
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    #expect(model.recentSessions.count == 10)
    #expect(model.recentSessions.first?.date == TrainClock.date(month: 10, day: 12, hour: 18))
}

@MainActor @Test func sheetRemindsDeclaredPainAreas() async throws {
    let fixture = TrainFixture()
    try await fixture.saveProfile(painAreas: [.shoulders])
    let dips = ExerciseSheetModel(environment: fixture.environment, reference: .content(id: "dips"))
    await dips.load()
    #expect(dips.painReminder?.contains("épaules") == true)
    let curl = ExerciseSheetModel(environment: fixture.environment, reference: .content(id: "barbell-curl"))
    await curl.load()
    #expect(curl.painReminder == nil)

    let healthy = TrainFixture()
    try await healthy.saveProfile()
    let healthyDips = ExerciseSheetModel(environment: healthy.environment, reference: .content(id: "dips"))
    await healthyDips.load()
    #expect(healthyDips.painReminder == nil)
}

@MainActor @Test func settingTheIncrementStoresExerciseSettings() async throws {
    let fixture = TrainFixture()
    try await fixture.saveProfile()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    #expect(model.increment == 2.5)
    let existing = ExerciseSettings(exercise: bench, warmupSetCount: 3, createdAt: fixture.now, updatedAt: fixture.now)
    try await fixture.environment.exerciseSettings.save(existing)

    await model.setIncrement(1.25)
    #expect(model.increment == 1.25)
    let stored = try #require(try await fixture.environment.exerciseSettings.settings(for: bench))
    #expect(stored.incrementKg == 1.25)
    #expect(stored.warmupSetCount == 3)
    #expect(stored.id == existing.id)

    let reloaded = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await reloaded.load()
    #expect(reloaded.increment == 1.25)
}

@MainActor @Test func settingTheIncrementStaysOnTheQuarterKiloGrid() async throws {
    let fixture = TrainFixture()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    await model.setIncrement(0)
    #expect(model.increment == 0.25)
    await model.setIncrement(42)
    #expect(model.increment == 20)
    await model.setIncrement(2.6)
    #expect(model.increment == 2.5)
}

@MainActor @Test func sheetForACustomExerciseShowsOnlyWhatExists() async throws {
    let fixture = TrainFixture()
    try await fixture.saveProfile(painAreas: [.shoulders, .knees])
    let custom = userExercise(name: "Zercher squat")
    try await fixture.store(custom)
    let model = ExerciseSheetModel(environment: fixture.environment, reference: .user(id: custom.id))
    await model.load()
    #expect(model.info?.name == "Zercher squat")
    #expect(model.info?.content == nil)
    #expect(model.painReminder == nil)
    #expect(model.alternatives.isEmpty)
    #expect(model.userExercise == custom)
    #expect(model.increment == 5)
}

@MainActor @Test func sheetForAnUnknownExerciseHasNoInfo() async {
    let model = ExerciseSheetModel(environment: TrainFixture().environment, reference: .content(id: "does-not-exist"))
    await model.load()
    #expect(model.info == nil)
    #expect(model.chart.isEmpty)
}

@MainActor @Test func sheetColoursPrimaryMusclesBrighterThanSecondaryOnes() async {
    let model = ExerciseSheetModel(environment: TrainFixture().environment, reference: bench)
    await model.load()
    #expect(model.muscleLevels[.chest] == 4)
    #expect(model.muscleLevels[.triceps] == 2)
}

@MainActor @Test func sheetSummarisesTheChartForVoiceOver() async throws {
    let fixture = try await benchFixture()
    let model = ExerciseSheetModel(environment: fixture.environment, reference: bench)
    await model.load()
    let summary = try #require(model.chartSummary)
    #expect(summary.contains("3 séances"))
    #expect(summary.contains("2 octobre"))
    #expect(summary.contains("26 octobre"))
    #expect(summary.contains("80"))
    #expect(summary.contains("81,6"))
    let empty = ExerciseSheetModel(environment: TrainFixture().environment, reference: bench)
    await empty.load()
    #expect(empty.chartSummary == nil)
}
