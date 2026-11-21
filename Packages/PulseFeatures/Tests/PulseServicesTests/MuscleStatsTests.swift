import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct MuscleStatsTests {
    private let now = TestClock.date("2026-11-20T12:00")
    private var calendar: Calendar { TestClock.calendar }

    private static func userExercise(_ name: String, primary: Muscle, secondary: [Muscle] = [], pattern: MovementPattern,
                                     region: BodyRegion) -> UserExercise {
        let date = Date(timeIntervalSince1970: 0)
        return UserExercise(name: name, primaryMuscle: primary, secondaryMuscles: secondary, equipment: .barbell, pattern: pattern,
                            region: region, isUnilateral: false, defaultIncrementKg: 2.5, defaultRestSeconds: 90,
                            createdAt: date, updatedAt: date)
    }

    private static let press = userExercise("Développé", primary: .chest, secondary: [.triceps], pattern: .horizontalPush,
                                            region: .upper)
    private static let row = userExercise("Tirage", primary: .lats, secondary: [.biceps], pattern: .horizontalPull, region: .upper)
    private static let squat = userExercise("Squat", primary: .quads, secondary: [.glutes], pattern: .squat, region: .lower)
    private static let plank = userExercise("Gainage", primary: .abs, pattern: .coreStability, region: .core)
    /// Un exercice qui sollicite dix muscles, pour dépasser les huit de `top`.
    private static let everything = userExercise(
        "Tout", primary: .chest, secondary: [.frontDelts, .sideDelts, .rearDelts, .traps, .lats, .upperBack, .lowerBack, .biceps, .triceps],
        pattern: .horizontalPush, region: .upper)

    private let directory = ExerciseDirectory(
        library: ContentLibrary(catalog: ExerciseCatalog(schemaVersion: 1, contentVersion: "test", exercises: []), templates: []),
        userExercises: [press, row, squat, plank, everything])

    private func reference(_ exercise: UserExercise) -> ExerciseReference { .user(id: exercise.id) }

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
    }

    private func sets(_ exercise: ExerciseReference, count: Int, type: SetType = .working) -> [WorkoutSet] {
        (0..<count).map { WorkoutSet(order: $0, exercise: exercise, exerciseName: "Exercice", setType: type) }
    }

    private func session(daysAgo: Int = 1, kind: SessionKind = .strength, status: SessionStatus = .completed,
                         sets: [WorkoutSet] = []) -> WorkoutSession {
        let start = day(daysAgo).addingTimeInterval(7 * 3_600)
        return WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3_600), kind: kind, source: .pulse, status: status,
                              title: "Séance", sets: sets, createdAt: start, updatedAt: start)
    }

    private func stats(_ sessions: [WorkoutSession], historyStart: Date? = nil, period: StatsPeriod = .month) -> MuscleStats {
        MuscleStats.make(sessions: sessions, directory: directory, historyStart: historyStart, period: period, now: now,
                         calendar: calendar)
    }

    @Test func weightsCountPrimaryOneSecondaryHalf() {
        let result = stats([session(sets: sets(reference(Self.press), count: 3))])
        #expect(result.weights[.chest] == 3)
        #expect(result.weights[.triceps] == 1.5)
        #expect(result.top.map(\.muscle) == [.chest, .triceps])
        #expect(result.top.map(\.sets) == [3, 1.5])
        #expect(result.strengthSessions == 1)
    }

    @Test func warmupsAndAbandonedSessionsAreSkipped() {
        let press = reference(Self.press)
        let mixed = session(sets: sets(press, count: 2) + sets(press, count: 5, type: .warmup))
        let abandoned = session(status: .abandoned, sets: sets(press, count: 4))
        let run = session(kind: .run, sets: sets(press, count: 4))
        let old = session(daysAgo: 45, sets: sets(press, count: 4))
        let result = stats([mixed, abandoned, run, old])
        #expect(result.weights[.chest] == 2)
        #expect(result.push == 2)
        #expect(result.strengthSessions == 1)
    }

    @Test func unknownExerciseIsIgnored() {
        let known = session(sets: sets(reference(Self.press), count: 3))
        let unknown = session(sets: sets(.user(id: UUID()), count: 6) + sets(.content(id: "supprime"), count: 2))
        let result = stats([known, unknown])
        #expect(result.weights == stats([known]).weights)
        #expect(result.push == 3)
        #expect(result.pull == 0 && result.upper == 3 && result.lower == 0)
        // La séance reste comptée même quand ses exercices ne se résolvent pas.
        #expect(result.strengthSessions == 2)
    }

    @Test func topIsCappedAtEight() {
        let result = stats([session(sets: sets(reference(Self.everything), count: 2))])
        #expect(result.weights.count == 10)
        #expect(result.top.count == 8)
        #expect(result.top.first?.muscle == .chest)
        // À égalité (1 série chacun), l'ordre de Muscle.allCases : frontDelts, sideDelts, rearDelts, traps, lats, upperBack, lowerBack.
        #expect(result.top.map(\.muscle) == [.chest, .frontDelts, .sideDelts, .rearDelts, .traps, .lats, .upperBack, .lowerBack])
    }

    @Test func balance() {
        let result = stats([session(sets: sets(reference(Self.press), count: 10) + sets(reference(Self.row), count: 5)
                                    + sets(reference(Self.plank), count: 4))])
        #expect(result.push == 10)
        #expect(result.pull == 5)
        #expect(result.isPushPullUnbalanced)
        #expect(result.upper == 15)
        #expect(result.lower == 0)
        #expect(result.isUpperLowerUnbalanced)
    }

    @Test func balancedAndEmptyRatiosAreNotFlagged() {
        let balanced = stats([session(sets: sets(reference(Self.press), count: 6) + sets(reference(Self.row), count: 5)
                                      + sets(reference(Self.squat), count: 10))])
        #expect(!balanced.isPushPullUnbalanced)
        #expect(balanced.lower == 10 && balanced.upper == 11 && !balanced.isUpperLowerUnbalanced)
        let none = stats([])
        #expect(!none.isPushPullUnbalanced && !none.isUpperLowerUnbalanced)
        #expect(none.weights.isEmpty && none.top.isEmpty && none.strengthSessions == 0)
    }

    private var eightSessionsWithPlank: [WorkoutSession] {
        (0..<8).map { session(daysAgo: $0 * 3, sets: $0 == 0 ? sets(reference(Self.plank), count: 2) : []) }
    }

    @Test func neglectedNeedsThirtyDaysAndRegularTraining() {
        let month = stats(eightSessionsWithPlank, period: .month)
        #expect(month.neglected.map(\.group).contains(.core))
        #expect(stats(eightSessionsWithPlank, period: .week).neglected.isEmpty)
        let rare = [session(daysAgo: 1, sets: sets(reference(Self.plank), count: 2)), session(daysAgo: 10)]
        #expect(stats(rare, period: .month).neglected.isEmpty)
    }

    @Test func neglectedGroupsAreOrderedByWeeklySetsThenGroupOrder() throws {
        let weeks = 30.0 / 7
        let result = stats(eightSessionsWithPlank, period: .month)
        // Tous les groupes sans série d'abord, dans l'ordre de MuscleGroup.allCases, puis le tronc.
        #expect(result.neglected.map(\.group) == [.chest, .back, .shoulders, .arms, .legs, .core])
        let core = try #require(result.neglected.last)
        #expect(abs(core.weeklySets - 2 / weeks) < 1e-9)
        #expect(core.muscles == [MuscleLoad(muscle: .abs, sets: 2)])
        #expect(result.neglected.first?.muscles.isEmpty == true)
    }

    @Test func groupAtFourWeeklySetsIsNotNeglected() {
        // 4 séries pondérées par semaine sur 30 jours = 120/7 séries : 18 séries de squat (quads 18, fessiers 9) couvrent les jambes.
        let sessions = (0..<8).map { session(daysAgo: $0 * 3, sets: $0 < 3 ? sets(reference(Self.squat), count: 6) : []) }
        let result = stats(sessions, period: .month)
        #expect(!result.neglected.map(\.group).contains(.legs))
        #expect(result.neglected.map(\.group).contains(.core))
    }

    @Test func shortHistoryDoesNotMakeGroupsNeglected() {
        // 13 semaines d'historique, 5 séances par semaine, 12 séries de pectoraux par semaine : sur l'année entière (52 semaines)
        // la moyenne tomberait à 3, mais seules les 13 semaines d'historique comptent.
        let sessions = (0..<91).filter { $0 % 7 < 5 }.map { daysAgo in
            session(daysAgo: daysAgo, sets: daysAgo % 7 == 0 ? sets(reference(Self.press), count: 12) : [])
        }
        let result = stats(sessions, historyStart: day(90), period: .year)
        #expect(!result.neglected.map(\.group).contains(.chest))
        // Les autres groupes, sans série, restent délaissés.
        #expect(result.neglected.map(\.group).contains(.legs))
        // Sans l'historique, la période entière sert de diviseur et les pectoraux passent sous le seuil.
        #expect(stats(sessions, period: .year).neglected.map(\.group).contains(.chest))
    }

    @Test func historyShorterThanTwoWeeksHasNoNeglectedGroups() {
        let daily = (0..<14).map { session(daysAgo: $0, sets: $0 == 0 ? sets(reference(Self.plank), count: 2) : []) }
        // 14 jours d'historique : la règle s'applique.
        #expect(!stats(daily, historyStart: day(13)).neglected.isEmpty)
        // 13 jours : trop court.
        #expect(stats(daily, historyStart: day(12)).neglected.isEmpty)
        #expect(stats(daily, historyStart: day(0)).neglected.isEmpty)
    }
}
