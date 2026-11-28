import Foundation
import PulseDomain
import PulseServices
import Testing

/// Le plateau d'un exercice sur des séances fixées : le 1RM estimé (Brzycki) de la meilleure série de chaque séance, quatre
/// séances comptées sans progrès et trois semaines au moins.
struct PlateauDetectorTests {
    private let now = TestClock.date("2026-11-20T18:00")
    private let bench = ExerciseReference.content(id: "bench-press-barbell")
    private let fatigue = SessionAdjustment(kind: .rest, reason: "Repos rallongés de 45 secondes", value: 45)

    private func day(_ daysAgo: Int) -> Date {
        TestClock.calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
    }

    /// Une séance de bench il y a `daysAgo` jours : un échauffement, puis les séries `(charge, répétitions)`.
    private func session(_ daysAgo: Int, _ sets: [(Double, Int)], status: SessionStatus = .completed,
                         applied: [SessionAdjustment] = [], refused: [SessionAdjustment] = []) -> WorkoutSession {
        let start = day(daysAgo)
        let warmup = WorkoutSet(order: 0, exercise: bench, exerciseName: "Bench", setType: .warmup, actualWeightKg: 120,
                                actualReps: 5)
        let working = sets.enumerated().map { index, set in
            WorkoutSet(order: index + 1, exercise: bench, exerciseName: "Bench", setType: .working, actualWeightKg: set.0,
                       actualReps: set.1)
        }
        return WorkoutSession(startedAt: start, kind: .strength, source: .pulse, status: status, title: "Push",
                              appliedAdjustments: applied, refusedAdjustments: refused, sets: [warmup] + working,
                              createdAt: start, updatedAt: start)
    }

    private func plateau(_ sessions: [WorkoutSession], loadKind: LoadKind = .external) -> ExercisePlateau? {
        PlateauDetector.plateau(for: bench, in: sessions, loadKind: loadKind, now: now, calendar: TestClock.calendar)
    }

    /// 80 × 5 (90 kg estimés) il y a 30 jours, puis quatre séances qui n'en font pas plus en 4 semaines.
    private var stalled: [WorkoutSession] {
        [session(37, [(77.5, 5)]), session(30, [(80, 5), (80, 4)]), session(23, [(80, 5)]), session(16, [(77.5, 6)]),
         session(9, [(80, 4)]), session(2, [(80, 5)])]
    }

    @Test func fourSessionsWithoutProgressOverThreeWeeksAreAPlateau() throws {
        let found = try #require(plateau(stalled))
        #expect(found.bestKg == 90 && found.bestDate == day(30))
        #expect(found.recentBestKg == 90)   // 80 × 5 refait, sans mieux
        #expect(found.sessionCount == 4 && found.lastDate == day(2) && found.excludedCount == 0)
    }

    @Test func aBetterSessionInTheWindowIsProgress() {
        var sessions = stalled
        sessions[4] = session(9, [(82.5, 5)])
        #expect(plateau(sessions) == nil)
    }

    @Test func threeSessionsSinceTheBestAreNotEnough() {
        #expect(plateau(Array(stalled.dropLast())) == nil)
    }

    @Test func fourSessionsInLessThanThreeWeeksAreNotAPlateau() {
        let sessions = [session(20, [(77.5, 5)]), session(18, [(80, 5)]), session(14, [(80, 5)]), session(10, [(80, 4)]),
                        session(6, [(77.5, 6)]), session(2, [(80, 5)])]
        // Du meilleur (18 jours) à la dernière séance (2 jours) : 16 jours.
        #expect(plateau(sessions) == nil)
    }

    @Test func fatigueAndDeloadSessionsDoNotCount() throws {
        // Le meilleur à 30 jours, puis deux séances comptées, une en fatigue (appliquée), une en décharge : pas encore de plateau.
        let deload = SessionAdjustment(kind: .deload, reason: "Semaine de décharge", value: 0.4)
        let partial = [session(37, [(77.5, 5)]), session(30, [(80, 5)]), session(25, [(80, 5)]),
                       session(20, [(70, 5)], applied: [fatigue]), session(15, [(72.5, 5)], applied: [deload]),
                       session(10, [(80, 4)])]
        #expect(plateau(partial) == nil)
        let found = try #require(plateau(partial + [session(5, [(77.5, 6)]), session(2, [(80, 5)])]))
        #expect(found.sessionCount == 4 && found.excludedCount == 2)
    }

    @Test func aReturnAfterAPauseRestartsTheCount() throws {
        // Trois semaines sans bench entre 63 et 42 jours. La séance de reprise, aux charges baissées, ne compte pas, et le
        // meilleur d'avant la pause (85 × 5) n'est plus une référence.
        let resumed = [session(70, [(77.5, 5)]), session(63, [(85, 5)]), session(42, [(72.5, 5)]), session(35, [(80, 5)]),
                       session(28, [(80, 4)]), session(21, [(77.5, 6)]), session(14, [(80, 5)])]
        #expect(plateau(resumed) == nil)
        let found = try #require(plateau(resumed + [session(7, [(80, 4)])]))
        #expect(found.bestKg == 90 && found.bestDate == day(35))
        #expect(found.sessionCount == 4 && found.excludedCount == 0)
    }

    @Test func refusedFatigueAdjustmentsStillMarkAFatigueDay() {
        let cap = SessionAdjustment(kind: .rpeCap, reason: "Effort plafonné à RPE 7,5", value: 7.5)
        let normalRest = SessionAdjustment(kind: .rest, reason: "Repos rallongés de 15 secondes", value: 15)
        let deload = SessionAdjustment(kind: .deload, reason: "Semaine de décharge", value: 0.4)
        #expect(!PlateauDetector.counts(session(1, [], refused: [cap])))
        #expect(!PlateauDetector.counts(session(1, [], refused: [fatigue])))
        #expect(!PlateauDetector.counts(session(1, [], applied: [SessionAdjustment(kind: .volume, reason: "", value: -2)])))
        // Un jour normal (repos +15 s), une décharge refusée ou une séance sans score comptent.
        #expect(PlateauDetector.counts(session(1, [], applied: [normalRest])))
        #expect(PlateauDetector.counts(session(1, [], refused: [deload, normalRest])))
        #expect(PlateauDetector.counts(session(1, [])))
    }

    @Test func setsBeyondTwelveRepsAndSessionsInProgressAreIgnored() {
        var sessions = stalled
        sessions[3] = session(16, [(60, 15)])                       // pas d'estimation au-delà de 12 répétitions
        #expect(plateau(sessions) == nil)
        sessions[3] = session(16, [(80, 5)], status: .inProgress)
        #expect(plateau(sessions) == nil)
    }

    @Test func abandonedSessionsCountLikeTheSheetCurve() throws {
        // Comme la courbe et les records de la fiche : les séries faites d'une séance abandonnée comptent.
        var sessions = stalled
        sessions[3] = session(16, [(77.5, 6)], status: .abandoned)
        #expect(try #require(plateau(sessions)).sessionCount == 4)
    }

    @Test func repeatingTheSameBestDoesNotRestartTheClock() throws {
        // 80 × 5 trois fois par semaine pendant 6 semaines : le niveau est atteint dès la première séance, il y a 41 jours.
        let sessions = stride(from: 41, through: 1, by: -2).map { session($0, [(80, 5)]) }
        let found = try #require(plateau(sessions))
        #expect(found.bestDate == day(41) && found.lastDate == day(1))
        #expect(found.sessionCount == sessions.count - 1)
    }

    @Test func alternatingFiveAndFourRepsIsStillAPlateau() throws {
        // 80 × 5 puis 80 × 4 en alternance : chaque 80 × 5 bat la séance d'avant, sans jamais dépasser 90 kg estimés.
        let sessions = [session(30, [(80, 5)]), session(23, [(80, 4)]), session(16, [(80, 5)]), session(9, [(80, 4)]),
                        session(2, [(80, 5)])]
        #expect(try #require(plateau(sessions)).sessionCount == 4)
    }

    @Test func aReboundAfterADipIsNotAPlateau() {
        // 100 × 5 il y a 45 et 38 jours, une maladie, puis une remontée de 80 à 87,5 kg en 3 semaines, sous l'ancien niveau.
        let sessions = [session(45, [(100, 5)]), session(38, [(100, 5)]), session(23, [(80, 5)]), session(16, [(82.5, 5)]),
                        session(9, [(85, 5)]), session(2, [(87.5, 5)])]
        #expect(plateau(sessions) == nil)
    }

    @Test func onlyExternalLoadsHaveAPlateau() {
        #expect(plateau(stalled, loadKind: .bodyweight) == nil)
        #expect(plateau(stalled, loadKind: .assisted) == nil)
    }

    @Test func anExerciseLeftAsideHasNoPlateau() {
        // La dernière séance date de 32 jours : l'exercice n'est plus travaillé.
        let old = stalled.map { session in
            var moved = session
            moved.startedAt = session.startedAt.addingTimeInterval(-30 * 86_400)
            return moved
        }
        #expect(plateau(old) == nil)
    }

    @Test func aBestFromBeforeALongBreakIsForgotten() {
        // 100 × 5 il y a 160 jours, puis une reprise sous ce niveau mais en progrès : pas de plateau.
        let sessions = [session(160, [(100, 5)]), session(30, [(70, 5)]), session(23, [(72.5, 5)]), session(16, [(75, 5)]),
                        session(9, [(77.5, 5)]), session(2, [(80, 5)])]
        #expect(plateau(sessions) == nil)
    }

    @Test func theExplanationSaysHowItIsComputed() throws {
        let found = try #require(plateau(stalled))
        #expect(found.explanation(calendar: TestClock.calendar) == """
            Pulse estime ton 1RM avec la formule de Brzycki et garde la meilleure série de chaque séance. Ton meilleur 1RM estimé \
            des 3 derniers mois : 90 kg le 21 octobre. Les 4 séances suivantes, sur 4 semaines, n'ont pas fait mieux (au mieux \
            90 kg).
            """)
        var excluded = found
        excluded.excludedCount = 2
        #expect(excluded.explanation(calendar: TestClock.calendar, spoken: true).hasSuffix(
            "(au mieux 90 kilos). 2 séances faites en fatigue, en décharge ou en reprise ne sont pas comptées."))
        #expect(ExercisePlateau.tips(variant: "Développé haltères").last
            == "Le remplacer quelques semaines par une variante, comme Développé haltères.")
    }
}
