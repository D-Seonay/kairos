import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// Les nuits et les séances de l'écran « Pourquoi » : la nuit de la maquette (VFC 44 pour 53,66, FC 54 pour 49, 5 h 10 de sommeil,
/// score 58) sur le Push du lundi 2 novembre, que chaque test retouche.
enum WhyFixture {
    static let library = ContentLibrary.bundled

    static func recovery(_ edit: (inout DailyRecovery) -> Void = { _ in }) -> DailyRecovery {
        let now = TodayClock.date("2026-11-02T08:00")
        var recovery = DailyRecovery(
            day: TodayClock.date("2026-11-02T00:00"), score: 58, category: .moderateFatigue, isEstimated: false,
            hrvScore: 59, restingHeartRateScore: 58, sleepScore: 56, sdnnMs: 44, sdnnBaselineMs: 53.66,
            restingHeartRate: 54, restingHeartRateBaseline: 49, asleepMinutes: 310, calibration: .ready,
            createdAt: now, updatedAt: now)
        edit(&recovery)
        return recovery
    }

    /// Le même score, rangé dans sa catégorie.
    static func recovery(score: Double, _ edit: (inout DailyRecovery) -> Void = { _ in }) -> DailyRecovery {
        recovery {
            $0.score = score
            $0.category = RecoveryCategory(score: score)
            edit(&$0)
        }
    }

    /// Un score estimé sur un check-in, sans aucune mesure de la nuit.
    static func estimated(score: Double) -> DailyRecovery {
        recovery(score: score) {
            $0.isEstimated = true
            $0.hrvScore = nil
            $0.restingHeartRateScore = nil
            $0.sleepScore = nil
            $0.sdnnMs = nil
            $0.sdnnBaselineMs = nil
            $0.restingHeartRate = nil
            $0.restingHeartRateBaseline = nil
            $0.asleepMinutes = nil
            $0.missingFactors = Factor.allCases
            $0.calibration = .calibrating(nights: 0)
        }
    }

    static func checkIn(sleep: Int, pain: Int, motivation: Int, score: Double) -> CheckIn {
        let now = TodayClock.date("2026-11-02T08:00")
        return CheckIn(day: TodayClock.date("2026-11-02T00:00"),
                       answers: CheckInAnswers(sleep: sleep, pain: pain, motivation: motivation),
                       score: score, createdAt: now, updatedAt: now)
    }

    /// Le jour prévu par `templateID` à la date `text` : PPL 3 le lundi 2 novembre = Push, le mardi = repos ;
    /// runner-strength le jeudi 5 novembre = Fractionné.
    static func plannedDay(_ templateID: String = "ppl-3", on text: String = "2026-11-02T08:00") throws -> PlannedDay {
        let now = TodayClock.date(text)
        let template = try #require(library.programTemplate(id: templateID))
        let program = ProgramAdopter(library: library).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
        return TodayPlanner.plan(program: program, on: now, calendar: TodayClock.calendar)
    }

    static func session(_ plannedDay: PlannedDay, for recovery: DailyRecovery) -> TodaySession {
        TodaySession(plannedDay: plannedDay, recovery: recovery)
    }

    /// Le contenu de l'écran pour un score et un jour prévu.
    static func content(_ recovery: DailyRecovery, plannedDay: PlannedDay? = nil, checkIn: CheckIn? = nil,
                        userExercises: [UserExercise] = [], loadAdjustments: [SessionAdjustment]? = nil) throws -> WhyContent {
        let planned = try plannedDay ?? Self.plannedDay()
        let directory = ExerciseDirectory(library: library, userExercises: userExercises)
        return WhyContent.make(recovery: recovery, session: session(planned, for: recovery), checkIn: checkIn, directory: directory,
                               loadAdjustments: loadAdjustments)
    }

    /// Le nom français d'un exercice du contenu embarqué.
    static func name(_ id: String) throws -> String {
        try #require(library.exercise(id: id)).name.fr
    }
}
