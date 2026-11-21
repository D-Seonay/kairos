import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct RecordStatsTests {
    private let now = TestClock.date("2026-11-20T12:00")
    private var calendar: Calendar { TestClock.calendar }

    private let squat = ExerciseReference.content(id: "back-squat-barbell")
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let deadlift = ExerciseReference.content(id: "deadlift-barbell")
    private let press = ExerciseReference.content(id: "overhead-press-barbell")
    private let curl = ExerciseReference.user(id: UUID())
    private let dips = ExerciseReference.user(id: UUID())

    private let directory = ExerciseDirectory(
        library: ContentLibrary(catalog: ExerciseCatalog(schemaVersion: 1, contentVersion: "test", exercises: []), templates: []),
        userExercises: [])

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))?.addingTimeInterval(7 * 3_600) ?? now
    }

    private func record(_ exercise: ExerciseReference, _ value: Double, daysAgo: Int = 3, kind: RecordKind = .estimatedOneRepMax,
                        name: String = "Exercice", setID: UUID? = nil) -> PersonalRecord {
        PersonalRecord(exercise: exercise, exerciseName: name, kind: kind, value: value, date: day(daysAgo), setID: setID,
                       createdAt: now, updatedAt: now)
    }

    private func lifting(_ exercise: ExerciseReference, sessions count: Int) -> [WorkoutSession] {
        (0..<count).map { index in
            session(daysAgo: 10 + index, sets: [WorkoutSet(order: 0, exercise: exercise, exerciseName: "Exercice", setType: .working)])
        }
    }

    private func session(daysAgo: Int = 1, kind: SessionKind = .strength, status: SessionStatus = .completed,
                         distance: Double? = nil, minutes: Double? = nil, sets: [WorkoutSet] = []) -> WorkoutSession {
        let start = day(daysAgo)
        return WorkoutSession(startedAt: start, kind: kind, source: .pulse, status: status, title: "Séance",
                              durationMinutes: minutes, distanceMeters: distance, sets: sets, createdAt: start, updatedAt: start)
    }

    private func stats(records: [PersonalRecord] = [], sessions: [WorkoutSession] = [], period: StatsPeriod = .month) -> RecordStats {
        RecordStats.make(records: records, sessions: sessions, directory: directory, period: period, now: now, calendar: calendar)
    }

    @Test func mainLiftsComeFirstInOrder() {
        let records = [record(deadlift, 150), record(curl, 40, name: "Curl"), record(squat, 120), record(bench, 100)]
        let result = stats(records: records, sessions: lifting(curl, sessions: 5))
        #expect(result.strength.map(\.exercise) == [squat, bench, deadlift, curl])
    }

    @Test func otherExercisesNeedFiveSessions() {
        let records = [record(curl, 40, name: "Curl")]
        #expect(stats(records: records, sessions: lifting(curl, sessions: 4)).strength.isEmpty)
        #expect(stats(records: records, sessions: lifting(curl, sessions: 5)).strength.map(\.exercise) == [curl])
    }

    @Test func sessionCountSkipsWarmupsAndUnfinishedSessions() {
        let warmups = (0..<5).map { index in
            session(daysAgo: 10 + index, sets: [WorkoutSet(order: 0, exercise: curl, exerciseName: "Curl", setType: .warmup)])
        }
        let abandoned = (0..<5).map { index in
            session(daysAgo: 20 + index, status: .abandoned,
                    sets: [WorkoutSet(order: 0, exercise: curl, exerciseName: "Curl", setType: .working)])
        }
        #expect(stats(records: [record(curl, 40)], sessions: warmups + abandoned).strength.isEmpty)
    }

    @Test func exerciseWithoutRecordHasNoLine() {
        #expect(stats(sessions: lifting(curl, sessions: 6)).strength.isEmpty)
        #expect(stats(records: [record(squat, 100, kind: .maxWeight)]).strength.isEmpty)
    }

    @Test func otherExercisesAreSortedByName() {
        let records = [record(curl, 40, name: "Élévations"), record(dips, 30, name: "Curl")]
        let result = stats(records: records, sessions: lifting(curl, sessions: 5) + lifting(dips, sessions: 5))
        #expect(result.strength.map(\.name) == ["Curl", "Élévations"])
    }

    @Test func currentIsTheHighestValueAndGainIsAgainstBeforePeriod() {
        let records = [record(squat, 90, daysAgo: 60), record(squat, 95, daysAgo: 3)]
        let line = stats(records: records).strength.first
        #expect(line?.value == 95)
        #expect(line?.gain == 5)
        #expect(line?.isNew == true)
        #expect(line?.date == day(3))
    }

    @Test func gainIsNilWithoutEarlierRecordOrWhenCurrentIsEarlier() {
        let first = stats(records: [record(squat, 90, daysAgo: 3)]).strength.first
        #expect(first?.gain == nil)
        #expect(first?.isNew == true)
        let old = stats(records: [record(squat, 90, daysAgo: 60), record(squat, 100, daysAgo: 50)]).strength.first
        #expect(old?.value == 100)
        #expect(old?.gain == nil)
        #expect(old?.isNew == false)
    }

    @Test func tieKeepsTheEarliestRecord() {
        let records = [record(squat, 100, daysAgo: 3), record(squat, 100, daysAgo: 60)]
        let line = stats(records: records).strength.first
        #expect(line?.date == day(60))
        #expect(line?.isNew == false)
    }

    @Test func bodyweightExerciseShowsRepsRecord() {
        let records = [record(dips, 12, daysAgo: 60, kind: .repsAtWeight, name: "Dips"),
                       record(dips, 14, kind: .repsAtWeight, name: "Dips"), record(dips, 20, kind: .maxWeight, name: "Dips")]
        let line = stats(records: records, sessions: lifting(dips, sessions: 5)).strength.first
        #expect(line?.kind == .repsAtWeight)
        #expect(line?.value == 14)
        #expect(line?.gain == 2)
    }

    @Test func oneRepMaxWinsOverRepsAtWeight() {
        let records = [record(squat, 100), record(squat, 14, kind: .repsAtWeight)]
        #expect(stats(records: records).strength.first?.kind == .estimatedOneRepMax)
    }

    @Test func repsComeFromTheRecordSet() {
        let set = WorkoutSet(order: 0, exercise: squat, exerciseName: "Squat", setType: .working, actualWeightKg: 80, actualReps: 6)
        let result = stats(records: [record(squat, 96, setID: set.id)], sessions: [session(sets: [set])])
        #expect(result.strength.first?.weightKg == 80)
        #expect(result.strength.first?.reps == 6)
        #expect(stats(records: [record(squat, 96, setID: UUID())], sessions: [session(sets: [set])]).strength.first?.reps == nil)
    }

    @Test func nameFallsBackToTheRecordName() {
        #expect(stats(records: [record(squat, 100, name: "Squat barre")]).strength.first?.name == "Squat barre")
    }

    @Test func runTimeIsScaledFromAveragePace() {
        let result = stats(sessions: [session(kind: .run, distance: 10_200, minutes: 51)])
        #expect(result.runs.map(\.distance) == RunDistance.allCases)
        #expect(result.runs[0].seconds == 1_500)
        #expect(result.runs[1].seconds == 3_000)
        #expect(result.runs[2].seconds == nil)
        #expect(result.runs[2].date == nil)
    }

    @Test func fastestRunWinsAndNewMeansInsideThePeriod() {
        let old = session(daysAgo: 60, kind: .run, distance: 5_000, minutes: 20)
        let recent = session(daysAgo: 2, kind: .run, distance: 5_000, minutes: 25)
        let slower = stats(sessions: [old, recent]).runs[0]
        #expect(slower.seconds == 1_200)
        #expect(slower.date == day(60))
        #expect(slower.isNew == false)
        let faster = stats(sessions: [session(daysAgo: 60, kind: .run, distance: 5_000, minutes: 30), recent]).runs[0]
        #expect(faster.seconds == 1_500)
        #expect(faster.isNew == true)
    }

    @Test func runTieKeepsTheEarliestRun() {
        let early = session(daysAgo: 60, kind: .run, distance: 5_000, minutes: 25)
        let late = session(daysAgo: 2, kind: .run, distance: 5_000, minutes: 25)
        #expect(stats(sessions: [late, early]).runs[0].date == day(60))
    }

    @Test func runWithoutDurationOrDistanceIsSkipped() {
        let sessions = [session(kind: .run, distance: 10_000, minutes: nil), session(kind: .run, distance: 10_000, minutes: 0),
                        session(kind: .run, distance: nil, minutes: 50), session(kind: .run, distance: 4_000, minutes: 20),
                        session(kind: .run, status: .abandoned, distance: 10_000, minutes: 50),
                        session(kind: .ride, distance: 10_000, minutes: 20)]
        let result = stats(sessions: sessions)
        #expect(result.runs.count == 3)
        #expect(result.runs.allSatisfy { $0.seconds == nil && $0.date == nil && !$0.isNew })
    }

    @Test func emptyHistoryGivesNoStrengthAndThreeEmptyRuns() {
        let result = stats()
        #expect(result.strength.isEmpty)
        #expect(result.runs.count == 3)
    }
}
