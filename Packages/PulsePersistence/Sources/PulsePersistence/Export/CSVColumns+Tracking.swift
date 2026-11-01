import Foundation
import PulseDomain

/// Colonnes des tables de suivi : semaine datée, récupération, compléments, corps, records.
extension CSVColumns {
    static let scheduledDays: [CSVColumn<ScheduledDay>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "date") { $1.date($0.date) },
        .init(name: "program_id") { $1.uuid($0.programID) }, .init(name: "routine_day_id") { $1.uuid($0.routineDayID) },
        .init(name: "title") { item, _ in item.title }, .init(name: "kind") { $1.raw($0.kind) },
        .init(name: "status") { $1.raw($0.status) },
        .init(name: "moved_from_date") { $1.date($0.movedFromDate) }, .init(name: "move_reason") { $1.raw($0.moveReason) },
        .init(name: "move_reason_text") { item, _ in item.moveReasonText },
        .init(name: "validated_manually") { $1.bool($0.validatedManually) },
        .init(name: "session_id") { $1.uuid($0.sessionID) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let dailyRecoveries: [CSVColumn<DailyRecovery>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "day") { $1.date($0.day) }, .init(name: "score") { $1.num($0.score) },
        .init(name: "category") { $1.raw($0.category) }, .init(name: "is_estimated") { $1.bool($0.isEstimated) },
        .init(name: "hrv_score") { $1.num($0.hrvScore) }, .init(name: "resting_heart_rate_score") { $1.num($0.restingHeartRateScore) },
        .init(name: "sleep_score") { $1.num($0.sleepScore) }, .init(name: "sdnn_ms") { $1.num($0.sdnnMs) },
        .init(name: "sdnn_baseline_ms") { $1.num($0.sdnnBaselineMs) }, .init(name: "resting_heart_rate") { $1.num($0.restingHeartRate) },
        .init(name: "resting_heart_rate_baseline") { $1.num($0.restingHeartRateBaseline) },
        .init(name: "asleep_minutes") { $1.int($0.asleepMinutes) }, .init(name: "deep_minutes") { $1.int($0.deepMinutes) },
        .init(name: "missing_factors") { $1.list($0.missingFactors) }, .init(name: "calibration") { $1.calibration($0.calibration) },
        .init(name: "adjustments") { $1.json($0.adjustments) }, .init(name: "frozen_at") { $1.date($0.frozenAt) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let checkIns: [CSVColumn<CheckIn>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "day") { $1.date($0.day) },
        .init(name: "sleep_answer") { $1.int($0.answers.sleep) }, .init(name: "pain_answer") { $1.int($0.answers.pain) },
        .init(name: "motivation_answer") { $1.int($0.answers.motivation) }, .init(name: "score") { $1.num($0.score) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let supplements: [CSVColumn<Supplement>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "name") { item, _ in item.name }, .init(name: "form") { $1.raw($0.form) },
        .init(name: "dose") { $1.num($0.dose) }, .init(name: "unit") { $1.raw($0.unit) }, .init(name: "timing") { $1.raw($0.timing) },
        .init(name: "time_of_day_minutes") { $1.int($0.timeOfDayMinutes) }, .init(name: "days") { $1.raw($0.days) },
        .init(name: "custom_weekdays") { $1.list($0.customWeekdays) }, .init(name: "stock_doses") { $1.num($0.stockDoses) },
        .init(name: "low_stock_threshold") { $1.num($0.lowStockThreshold) },
        .init(name: "reminder_enabled") { $1.bool($0.reminderEnabled) },
        .init(name: "health_kit_type") { item, _ in item.healthKitType }, .init(name: "is_archived") { $1.bool($0.isArchived) },
        .init(name: "order") { $1.int($0.order) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let supplementIntakes: [CSVColumn<SupplementIntake>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "supplement_id") { $1.uuid($0.supplementID) },
        .init(name: "taken_at") { $1.date($0.takenAt) }, .init(name: "dose") { $1.num($0.dose) },
        .init(name: "written_to_health_kit") { $1.bool($0.writtenToHealthKit) },
        .init(name: "health_kit_uuid") { item, _ in item.healthKitUUID },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let bodyMeasurements: [CSVColumn<BodyMeasurement>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "date") { $1.date($0.date) },
        .init(name: "weight_kg") { $1.num($0.weightKg) }, .init(name: "body_fat_percent") { $1.num($0.bodyFatPercent) },
        .init(name: "source") { $1.raw($0.source) }, .init(name: "health_kit_uuid") { item, _ in item.healthKitUUID },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let personalRecords: [CSVColumn<PersonalRecord>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "content_exercise_id") { item, _ in item.exercise.contentID },
        .init(name: "user_exercise_id") { $1.uuid($0.exercise.userID) }, .init(name: "exercise_name") { item, _ in item.exerciseName },
        .init(name: "kind") { $1.raw($0.kind) }, .init(name: "value") { $1.num($0.value) },
        .init(name: "weight_kg") { $1.num($0.weightKg) },
        .init(name: "date") { $1.date($0.date) }, .init(name: "session_id") { $1.uuid($0.sessionID) },
        .init(name: "set_id") { $1.uuid($0.setID) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]
}
