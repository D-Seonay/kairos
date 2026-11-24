import Foundation
import PulseDomain
import PulsePersistence
import SwiftData

enum TestContainer {
    static func make() throws -> ModelContainer {
        try PersistenceStack.makeContainer(mode: .inMemory)
    }
}

/// Dates fixes pour les tests.
enum Fixed {
    static let t0 = Date(timeIntervalSince1970: 1_794_700_000)
    static let t1 = Date(timeIntervalSince1970: 1_794_700_001)
    static let t2 = Date(timeIntervalSince1970: 1_794_700_002)

    /// Calendrier grégorien de Paris, celui de tous les tests.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()
}

enum Sample {
    static func routineExercise(order: Int, exercise: ExerciseReference = .content(id: "bench-press-barbell"),
                                superset: Int? = nil) -> RoutineExercise {
        RoutineExercise(order: order, exercise: exercise, sets: 3, repsMin: 8, repsMax: 12, targetRPE: 8, restSeconds: 90,
                        supersetGroup: superset)
    }

    static func program(days: Int = 2) -> Program {
        let dayList = (0..<days).map { index in
            RoutineDay(order: index, name: "Jour \(index + 1)", kind: .strength, exercises: [
                routineExercise(order: 0), routineExercise(order: 1, exercise: .user(id: UUID()), superset: 1),
                routineExercise(order: 2, superset: 1)
            ])
        }
        return Program(name: "Programme", templateID: "ppl-3", sessionsPerWeek: days,
                       weekLayout: [dayList.first?.id, nil, dayList.last?.id, nil, nil, nil, nil], days: dayList,
                       createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func set(order: Int, exercise: ExerciseReference = .content(id: "bench-press-barbell"), type: SetType = .working) -> WorkoutSet {
        WorkoutSet(order: order, exercise: exercise, exerciseName: "Développé couché", setType: type, supersetGroup: order == 2 ? 1 : nil,
                   plannedWeightKg: 80, plannedReps: 8, actualWeightKg: 80, actualReps: order == 3 ? 3 : 8, rpe: 8, restSeconds: 120,
                   completedAt: Fixed.t1, isPersonalRecord: order == 1)
    }

    static func session(startedAt: Date = Fixed.t0, status: SessionStatus = .completed, sets: Int = 9) -> WorkoutSession {
        var all = (0..<sets).map { set(order: $0 + 1) }
        if !all.isEmpty {
            all[0].setType = .warmup
            all[all.count - 1].replacedExercise = .content(id: "chest-press-machine")
            all[all.count - 1].replacementReason = .machineBusy
        }
        return WorkoutSession(startedAt: startedAt, endedAt: startedAt.addingTimeInterval(3_600), kind: .strength, source: .pulse,
                              status: status, programID: UUID(), routineDayID: UUID(), title: "Push",
                              appliedAdjustments: [SessionAdjustment(kind: .volume, reason: "Fatigue modérée", value: -0.2),
                                                   SessionAdjustment(kind: .rest, reason: "Repos +45 s", value: 45)],
                              refusedAdjustments: [SessionAdjustment(kind: .rpeCap, reason: "Plafond 7,5", value: 7.5)],
                              overallRPE: 8, note: "Dos ok, \"lourd\" aujourd'hui", tonnageKg: 5_120, durationMinutes: 60,
                              sets: all, createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    /// Course importée d'Apple Health : source `.appleHealth`, jamais de séries.
    static func importedRun(startedAt: Date = Fixed.t0) -> WorkoutSession {
        WorkoutSession(startedAt: startedAt, endedAt: startedAt.addingTimeInterval(2_520), kind: .run, source: .appleHealth,
                       status: .completed, title: "Course", durationMinutes: 42, distanceMeters: 8_000,
                       averageHeartRate: 151, estimatedRPE: 6, healthKitUUID: "RUN", sets: [], createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func scheduledDay(date: Date = Fixed.t0) -> ScheduledDay {
        ScheduledDay(date: date, programID: UUID(), routineDayID: UUID(), title: "Legs", kind: .strength, status: .planned,
                     movedFromDate: date.addingTimeInterval(-86_400), moveReason: .antiInterferenceAfterHeavyLegs,
                     moveReasonText: "Fractionné vendredi", validatedManually: false, sessionID: nil,
                     createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func userExercise(name: String = "Rowing machine du coin", archived: Bool = false) -> UserExercise {
        UserExercise(name: name, primaryMuscle: .lats, secondaryMuscles: [.biceps, .rearDelts], equipment: .machine,
                     pattern: .horizontalPull, region: .upper, isUnilateral: false, defaultIncrementKg: 2.5,
                     defaultRestSeconds: 90, isArchived: archived,
                     createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func exerciseSettings(exercise: ExerciseReference = .content(id: "bench-press-barbell")) -> ExerciseSettings {
        ExerciseSettings(exercise: exercise, incrementKg: 1.25, warmupSetCount: 2, createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }
}

extension Sample {
    static func recovery(day: Date = Fixed.t0, score: Double = 72, estimated: Bool = false) -> DailyRecovery {
        DailyRecovery(day: day, score: score, category: RecoveryCategory(score: score), isEstimated: estimated,
                      hrvScore: estimated ? nil : 80, restingHeartRateScore: estimated ? nil : 60, sleepScore: 70,
                      sdnnMs: 50, sdnnBaselineMs: 48, restingHeartRate: 52, restingHeartRateBaseline: 50,
                      asleepMinutes: 420, deepMinutes: 80,
                      missingFactors: estimated ? [.hrv, .restingHeartRate] : [], calibration: .calibrating(nights: 7),
                      adjustments: [SessionAdjustment(kind: .rest, reason: "Repos +45 s", value: 45)], frozenAt: nil,
                      createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func checkIn(day: Date = Fixed.t0) -> CheckIn {
        CheckIn(day: day, answers: CheckInAnswers(sleep: 3, pain: 4, motivation: 2), score: 77.5, createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func supplement(name: String = "Créatine", order: Int = 0, archived: Bool = false) -> Supplement {
        Supplement(name: name, form: .powder, dose: 5, unit: .gram, timing: .afterWorkout, timeOfDayMinutes: nil, days: .custom,
                   customWeekdays: [.monday, .thursday], stockDoses: 60, lowStockThreshold: 10, reminderEnabled: true,
                   healthKitType: nil, isArchived: archived, order: order, createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func intake(supplementID: UUID, takenAt: Date = Fixed.t0) -> SupplementIntake {
        SupplementIntake(supplementID: supplementID, takenAt: takenAt, dose: 5, writtenToHealthKit: false, healthKitUUID: nil,
                         createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func measurement(date: Date = Fixed.t0) -> BodyMeasurement {
        BodyMeasurement(date: date, weightKg: 78.4, bodyFatPercent: 15.2, source: .appleHealth, healthKitUUID: "ABC",
                        createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func record(exercise: ExerciseReference = .content(id: "bench-press-barbell"), date: Date = Fixed.t0) -> PersonalRecord {
        PersonalRecord(exercise: exercise, exerciseName: "Développé couché", kind: .repsAtWeight, value: 10, weightKg: 80, date: date,
                       sessionID: UUID(), setID: UUID(), createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func cachedSample(kind: HealthSampleKind = .sdnn, start: Date = Fixed.t0) -> CachedHealthSample {
        CachedHealthSample(kind: kind, start: start, end: start.addingTimeInterval(60), value: kind == .sleep ? nil : 50,
                           sleepStage: kind == .sleep ? .deep : nil, distanceMeters: nil, averageHeartRate: nil, durationMinutes: nil,
                           healthKitUUID: "HK", sourceBundleID: "com.fitbit.FitbitMobile", fetchedAt: Fixed.t2)
    }

    static func snapshot() -> ActiveSessionSnapshot {
        ActiveSessionSnapshot(startedAt: Fixed.t0, updatedAt: Fixed.t1, payload: Data([1, 2, 3]))
    }
}

extension Sample {
    /// Course enregistrée par Pulse : FC moyenne 150 et RPE estimé 8, lus pendant la course.
    static func pulseRun(startedAt: Date = Fixed.t0) -> WorkoutSession {
        WorkoutSession(startedAt: startedAt, endedAt: startedAt.addingTimeInterval(1_800), kind: .run, source: .pulse,
                       status: .completed, title: "Footing", durationMinutes: 30, distanceMeters: 5_200,
                       averageHeartRate: 150, estimatedRPE: 8, sets: [], createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func runPoint(_ index: Int) -> RunTrackPoint {
        RunTrackPoint(timestamp: Fixed.t0.addingTimeInterval(Double(index) * 5), latitude: 48.85 + Double(index) * 0.0001,
                      longitude: 2.35, altitude: index.isMultiple(of: 2) ? 35 : nil, horizontalAccuracy: 5,
                      verticalAccuracy: index.isMultiple(of: 2) ? 3 : nil)
    }

    static func runTrack(sessionID: UUID = UUID()) -> RunTrack {
        RunTrack(id: sessionID, points: (0..<4).map(runPoint),
                 splits: [RunSplit(kilometer: 1, seconds: 330, distanceMeters: 1_000),
                          RunSplit(kilometer: 2, seconds: 172.5, distanceMeters: 480)],
                 elevationGainMeters: 12, createdAt: Fixed.t1, updatedAt: Fixed.t2)
    }

    static func runDraft(sessionID: UUID = UUID(), updatedAt: Date = Fixed.t1) -> RunDraft {
        RunDraft(sessionID: sessionID, launch: RunLaunch(title: "Footing", runType: .easy, targetMinutes: 30),
                 startedAt: Fixed.t0, pauses: [RunPause(start: Fixed.t0.addingTimeInterval(60), end: Fixed.t0.addingTimeInterval(90))],
                 points: (0..<3).map(runPoint), heartRates: [140, 152], locationDenied: false, updatedAt: updatedAt)
    }
}

extension Sample {
    /// Une photo de séance ; `seed` distingue les octets de l'image et de la vignette.
    static func sessionPhoto(sessionID: UUID, order: Int, createdAt: Date = Fixed.t0) -> SessionPhoto {
        SessionPhoto(id: UUID(), sessionID: sessionID, order: order, createdAt: createdAt, updatedAt: createdAt)
    }

    static func photoImage(seed: UInt8) -> PhotoImage {
        PhotoImage(image: Data(repeating: seed, count: 4_096) + Data([0xFF, 0xD9]), thumbnail: Data(repeating: seed &+ 100, count: 256))
    }
}

/// Un conteneur en mémoire prêt à l'emploi.
struct ModelContainerBox {
    let container: ModelContainer

    init() throws {
        container = try TestContainer.make()
    }
}
