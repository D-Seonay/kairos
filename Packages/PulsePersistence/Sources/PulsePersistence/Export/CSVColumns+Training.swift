import Foundation
import PulseDomain

/// Colonnes des tables d'entraînement, dans l'ordre de déclaration des entités.
enum CSVColumns {
    static let profile: [CSVColumn<UserProfile>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "sex") { $1.raw($0.sex) },
        .init(name: "birth_date") { $1.date($0.birthDate) }, .init(name: "height_cm") { $1.num($0.heightCm) },
        .init(name: "weight_kg") { $1.num($0.weightKg) }, .init(name: "strength_level") { $1.raw($0.strengthLevel) },
        .init(name: "running_level") { $1.raw($0.runningLevel) }, .init(name: "focus") { $1.num($0.focus) },
        .init(name: "training_days_per_week") { $1.int($0.trainingDaysPerWeek) },
        .init(name: "rest_weekdays") { $1.list($0.restWeekdays) },
        .init(name: "equipment_access") { $1.raw($0.equipmentAccess) }, .init(name: "pain_areas") { $1.list($0.painAreas) },
        .init(name: "weight_unit") { $1.raw($0.weightUnit) }, .init(name: "adaptation_enabled") { $1.bool($0.adaptationEnabled) },
        .init(name: "anti_interference_rules_disabled") { $1.list($0.antiInterferenceRulesDisabled) },
        .init(name: "upper_increment_kg") { $1.num($0.upperIncrementKg) },
        .init(name: "lower_increment_kg") { $1.num($0.lowerIncrementKg) }, .init(name: "bar_weight_kg") { $1.num($0.barWeightKg) },
        .init(name: "available_plates_kg") { $1.doubles($0.availablePlatesKg) },
        .init(name: "default_rest_seconds") { $1.int($0.defaultRestSeconds) },
        .init(name: "auto_warmup_enabled") { $1.bool($0.autoWarmupEnabled) }, .init(name: "theme") { $1.raw($0.theme) },
        .init(name: "morning_score_notification") { $1.bool($0.morningScoreNotification) },
        .init(name: "morning_score_deadline_minutes") { $1.int($0.morningScoreDeadlineMinutes) },
        .init(name: "supplement_reminders_enabled") { $1.bool($0.supplementRemindersEnabled) },
        .init(name: "rest_timer_notification_enabled") { $1.bool($0.restTimerNotificationEnabled) },
        .init(name: "onboarding_completed_at") { $1.date($0.onboardingCompletedAt) },
        .init(name: "active_program_id") { $1.uuid($0.activeProgramID) },
        .init(name: "deload_week_started_at") { $1.date($0.deloadWeekStartedAt) },
        .init(name: "deload_declined_at") { $1.date($0.deloadDeclinedAt) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let programs: [CSVColumn<Program>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "name") { item, _ in item.name },
        .init(name: "template_id") { item, _ in item.templateID }, .init(name: "sessions_per_week") { $1.int($0.sessionsPerWeek) },
        .init(name: "week_layout") { $1.json($0.weekLayout) }, .init(name: "is_archived") { $1.bool($0.isArchived) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let routineDays: [CSVColumn<(UUID, RoutineDay)>] = [
        .init(name: "id") { $1.uuid($0.1.id) }, .init(name: "program_id") { $1.uuid($0.0) },
        .init(name: "order") { $1.int($0.1.order) }, .init(name: "name") { item, _ in item.1.name },
        .init(name: "kind") { $1.raw($0.1.kind) }, .init(name: "run_type") { $1.raw($0.1.runType) },
        .init(name: "run_target_minutes") { $1.int($0.1.runTargetMinutes) }, .init(name: "run_target_km") { $1.num($0.1.runTargetKm) }
    ]

    static let routineExercises: [CSVColumn<(UUID, RoutineExercise)>] = [
        .init(name: "id") { $1.uuid($0.1.id) }, .init(name: "routine_day_id") { $1.uuid($0.0) },
        .init(name: "order") { $1.int($0.1.order) }, .init(name: "content_exercise_id") { item, _ in item.1.exercise.contentID },
        .init(name: "user_exercise_id") { $1.uuid($0.1.exercise.userID) }, .init(name: "sets") { $1.int($0.1.sets) },
        .init(name: "reps_min") { $1.int($0.1.repsMin) }, .init(name: "reps_max") { $1.int($0.1.repsMax) },
        .init(name: "target_rpe") { $1.num($0.1.targetRPE) }, .init(name: "rest_seconds") { $1.int($0.1.restSeconds) },
        .init(name: "superset_group") { $1.int($0.1.supersetGroup) }
    ]

    static let userExercises: [CSVColumn<UserExercise>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "name") { item, _ in item.name },
        .init(name: "primary_muscle") { $1.raw($0.primaryMuscle) }, .init(name: "secondary_muscles") { $1.list($0.secondaryMuscles) },
        .init(name: "equipment") { $1.raw($0.equipment) }, .init(name: "pattern") { $1.raw($0.pattern) },
        .init(name: "region") { $1.raw($0.region) }, .init(name: "is_unilateral") { $1.bool($0.isUnilateral) },
        .init(name: "default_increment_kg") { $1.num($0.defaultIncrementKg) },
        .init(name: "default_rest_seconds") { $1.int($0.defaultRestSeconds) }, .init(name: "is_archived") { $1.bool($0.isArchived) },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let workoutSessions: [CSVColumn<WorkoutSession>] = [
        .init(name: "id") { $1.uuid($0.id) }, .init(name: "started_at") { $1.date($0.startedAt) },
        .init(name: "ended_at") { $1.date($0.endedAt) }, .init(name: "kind") { $1.raw($0.kind) },
        .init(name: "source") { $1.raw($0.source) }, .init(name: "status") { $1.raw($0.status) },
        .init(name: "program_id") { $1.uuid($0.programID) }, .init(name: "routine_day_id") { $1.uuid($0.routineDayID) },
        .init(name: "title") { item, _ in item.title }, .init(name: "applied_adjustments") { $1.json($0.appliedAdjustments) },
        .init(name: "refused_adjustments") { $1.json($0.refusedAdjustments) }, .init(name: "overall_rpe") { $1.num($0.overallRPE) },
        .init(name: "note") { item, _ in item.note }, .init(name: "tonnage_kg") { $1.num($0.tonnageKg) },
        .init(name: "duration_minutes") { $1.num($0.durationMinutes) }, .init(name: "distance_meters") { $1.num($0.distanceMeters) },
        .init(name: "average_heart_rate") { $1.num($0.averageHeartRate) }, .init(name: "estimated_rpe") { $1.num($0.estimatedRPE) },
        .init(name: "health_kit_uuid") { item, _ in item.healthKitUUID },
        .init(name: "created_at") { $1.date($0.createdAt) }, .init(name: "updated_at") { $1.date($0.updatedAt) }
    ]

    static let workoutSets: [CSVColumn<(UUID, WorkoutSet)>] = [
        .init(name: "id") { $1.uuid($0.1.id) }, .init(name: "session_id") { $1.uuid($0.0) },
        .init(name: "order") { $1.int($0.1.order) }, .init(name: "content_exercise_id") { item, _ in item.1.exercise.contentID },
        .init(name: "user_exercise_id") { $1.uuid($0.1.exercise.userID) }, .init(name: "exercise_name") { item, _ in item.1.exerciseName },
        .init(name: "set_type") { $1.raw($0.1.setType) }, .init(name: "superset_group") { $1.int($0.1.supersetGroup) },
        .init(name: "planned_weight_kg") { $1.num($0.1.plannedWeightKg) }, .init(name: "planned_reps") { $1.int($0.1.plannedReps) },
        .init(name: "actual_weight_kg") { $1.num($0.1.actualWeightKg) }, .init(name: "actual_reps") { $1.int($0.1.actualReps) },
        .init(name: "rpe") { $1.num($0.1.rpe) }, .init(name: "rest_seconds") { $1.int($0.1.restSeconds) },
        .init(name: "completed_at") { $1.date($0.1.completedAt) }, .init(name: "is_personal_record") { $1.bool($0.1.isPersonalRecord) },
        .init(name: "replaced_content_exercise_id") { item, _ in item.1.replacedExercise?.contentID },
        .init(name: "replaced_user_exercise_id") { $1.uuid($0.1.replacedExercise?.userID) },
        .init(name: "replacement_reason") { $1.raw($0.1.replacementReason) }
    ]
}
