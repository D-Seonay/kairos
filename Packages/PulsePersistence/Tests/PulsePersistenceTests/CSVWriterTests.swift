import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func csvLineQuotesOnlyWhenNeeded() {
    #expect(CSVWriter.line(["a", nil, "1.5"]) == "a,,1.5")
    #expect(CSVWriter.line(["Dos ok, \"lourd\"", "x\ny"]) == "\"Dos ok, \"\"lourd\"\"\",\"x\ny\"")
    #expect(CSVWriter.line(["true", "2026-11-15T08:12:33+01:00"]) == "true,2026-11-15T08:12:33+01:00")
    #expect(CSVWriter.file(header: ["a", "b"], rows: [["1", nil]]) == "a,b\n1,\n")
}

@Test func workoutSetsHeaderIsExact() {
    let doc = ExportDocument.empty(exportedAt: Fixed.t0, appVersion: "1.0 (1)", schemaVersion: 1, contentVersion: "1.0.0", locale: "fr_FR")
    let tables = CSVTables.tables(from: doc, timeZone: TimeZone(identifier: "Europe/Paris") ?? .current)
    #expect(tables.count == StoreTable.exported.count)
    #expect(tables[.workoutSets]?.header == [
        "id", "session_id", "order", "content_exercise_id", "user_exercise_id", "exercise_name", "set_type", "superset_group",
        "planned_weight_kg", "planned_reps", "actual_weight_kg", "actual_reps", "rpe", "rest_seconds", "completed_at",
        "is_personal_record", "replaced_content_exercise_id", "replaced_user_exercise_id", "replacement_reason",
        "duration_seconds"
    ])
    #expect(tables[.profile]?.header.first == "id")
    #expect(tables[.routineExercises]?.header.prefix(3) == ["id", "routine_day_id", "order"])
}

@Test func csvTablesFlattenSampleData() throws {
    var session = Sample.session(sets: 2)
    session.sets[1].replacedExercise = .user(id: UUID())
    var doc = ExportDocument.empty(exportedAt: Fixed.t0, appVersion: "1.0 (1)", schemaVersion: 1, contentVersion: "1.0.0", locale: "fr_FR")
    doc.workoutSessions = [session]
    doc.programs = [Sample.program(days: 1)]
    doc.dailyRecoveries = [Sample.recovery(estimated: true)]
    doc.checkIns = [Sample.checkIn()]
    doc.profile = UserProfile(createdAt: Fixed.t1, updatedAt: Fixed.t2)
    let tables = CSVTables.tables(from: doc, timeZone: TimeZone(identifier: "Europe/Paris") ?? .current)
    let sets = try #require(tables[.workoutSets])
    #expect(sets.rows.count == 2 && sets.rows[0][1] == session.id.uuidString && sets.rows[0][6] == "warmup")
    #expect(sets.rows[1][16] == nil && sets.rows[1][17] != nil && sets.rows[1][18] == "machineBusy")
    #expect(sets.rows[0][8] == "80" && sets.rows[0][12] == "8")
    let sessions = try #require(tables[.workoutSessions])
    #expect(sessions.rows[0][sessions.header.firstIndex(of: "note") ?? 0] == "Dos ok, \"lourd\" aujourd'hui")
    #expect(sessions.rows[0][sessions.header.firstIndex(of: "applied_adjustments") ?? 0]?.contains("\"kind\":\"volume\"") == true)
    let recoveries = try #require(tables[.dailyRecoveries])
    #expect(recoveries.rows[0][recoveries.header.firstIndex(of: "missing_factors") ?? 0] == "hrv|restingHeartRate")
    #expect(recoveries.rows[0][recoveries.header.firstIndex(of: "calibration") ?? 0] == "calibrating:7")
    let checkIns = try #require(tables[.checkIns])
    #expect(checkIns.header.contains("sleep_answer") && checkIns.rows[0][checkIns.header.firstIndex(of: "pain_answer") ?? 0] == "4")
    #expect(tables[.routineDays]?.rows.count == 1 && tables[.routineExercises]?.rows.count == 3)
    let profile = try #require(tables[.profile])
    #expect(profile.rows[0][profile.header.firstIndex(of: "available_plates_kg") ?? 0] == "25|20|15|10|5|2.5|1.25")
    #expect(CSVTables.readme(for: doc).contains("workout_sets.csv"))
}
