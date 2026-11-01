import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct ProgramAdopterTests {
    private let library = ContentLibrary.bundled
    private let now = TestClock.date("2026-11-02T08:00")
    private var adopter: ProgramAdopter { ProgramAdopter(library: library) }

    private func template(_ id: String) throws -> ProgramTemplate {
        try #require(library.programTemplate(id: id))
    }

    private func contentIDs(_ day: RoutineDay) -> [String] {
        day.exercises.compactMap { $0.exercise.contentID }
    }

    @Test func fullGymWithoutConstraintsCopiesTheTemplate() throws {
        let ppl = try template("ppl-3")
        let reference = Program(template: ppl, now: now)
        let program = adopter.adopt(ppl, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
        #expect(program.days.map(contentIDs) == reference.days.map(contentIDs))
        #expect(program.templateID == "ppl-3")
        #expect(program.sessionsPerWeek == 3)
        let placed = program.weekLayout.map { id in id.flatMap { id in program.days.first { $0.id == id }?.name } }
        let expected = reference.weekLayout.map { id in id.flatMap { id in reference.days.first { $0.id == id }?.name } }
        #expect(placed == expected)
        #expect(program.weekLayout.map { $0 != nil } == [true, false, true, false, true, false, false])
    }

    @Test func homeGymReplacesMachinesWithoutDuplicates() throws {
        let program = adopter.adopt(try template("ppl-3"), equipment: .homeGym, painAreas: [], restWeekdays: [], now: now)
        let push = try #require(program.days.first)
        #expect(contentIDs(push) == ["bench-press-dumbbell", "incline-bench-press-dumbbell", "dumbbell-fly", "dips",
                                     "wrist-curl-cable", "reverse-crunch"])
        for day in program.days {
            let ids = contentIDs(day)
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test func replacementsKeepTheSetsAndRepsOfTheTemplate() throws {
        let ppl = try template("ppl-3")
        let program = adopter.adopt(ppl, equipment: .homeGym, painAreas: [], restWeekdays: [], now: now)
        let pushTemplate = try #require(ppl.days.first)
        let push = try #require(program.days.first)
        #expect(push.exercises.map(\.sets) == pushTemplate.exercises.map(\.sets))
        #expect(push.exercises.map(\.repsMax) == pushTemplate.exercises.map(\.repsMax))
        #expect(push.exercises.map(\.order) == Array(0..<pushTemplate.exercises.count))
    }

    @Test func restDaysSlideTheAdoptedWeek() throws {
        let program = adopter.adopt(try template("ppl-3"), equipment: .fullGym, painAreas: [], restWeekdays: [.monday], now: now)
        #expect(program.weekLayout.map { $0 != nil } == [false, true, true, false, true, false, false])
        #expect(program.sessionsPerWeek == 3)
    }

    @Test func sessionsPerWeekCountsThePlacedDays() throws {
        let program = adopter.adopt(try template("ppl-6"), equipment: .fullGym, painAreas: [],
                                    restWeekdays: [.saturday, .sunday], now: now)
        #expect(program.weekLayout.compactMap { $0 }.count == 5)
        #expect(program.sessionsPerWeek == 5)
    }

    @Test func shoulderPainReplacesDips() {
        #expect(adopter.substitute("dips", equipment: .fullGym, painAreas: [.shoulders], excluding: []) == "close-grip-bench-press")
    }

    @Test func noAcceptableAlternativeKeepsOriginal() {
        let result = adopter.substitute("overhead-press-barbell", equipment: .fullGym, painAreas: [.shoulders], excluding: [])
        #expect(result == "overhead-press-barbell")
    }

    @Test func usedExercisesAreSkipped() {
        let result = adopter.substitute("chest-press-machine", equipment: .homeGym, painAreas: [], excluding: ["bench-press-dumbbell"])
        #expect(result == "incline-bench-press-dumbbell")
    }

    @Test func allowedExerciseWithoutRiskIsKept() {
        let result = adopter.substitute("bench-press-barbell", equipment: .fullGym, painAreas: [.wrists], excluding: [])
        #expect(result == "bench-press-barbell")
    }

    @Test func unknownExerciseIsKept() {
        #expect(adopter.substitute("nope", equipment: .homeGym, painAreas: [.knees], excluding: []) == "nope")
    }
}
