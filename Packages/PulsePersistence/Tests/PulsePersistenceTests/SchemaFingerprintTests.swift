import Foundation
@testable import PulsePersistence
import SwiftData
import Testing

private let drift = "Un modèle partagé a changé : figer sa copie dans la version précédente du schéma avant de le modifier."

@Test func v1SchemaMatchesItsFrozenFingerprint() throws {
    try checkFingerprint(of: Schema(versionedSchema: PulseSchemaV1.self), against: "schema-v1")
}

@Test func v2SchemaMatchesItsFingerprint() throws {
    try checkFingerprint(of: Schema(versionedSchema: PulseSchemaV2.self), against: "schema-v2")
}

@Test func v2OnlyAddsTheTwoM3Fields() {
    let v1 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV1.self)))
    let v2 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV2.self)))
    #expect(v1.subtracting(v2).isEmpty)
    #expect(v2.subtracting(v1).compactMap { $0.split(separator: ":").first.map(String.init) }.sorted()
        == ["StoredDailyRecovery.originalSessionChosen", "StoredProfile.firstName"])
}

@Test func v3SchemaMatchesItsFingerprint() throws {
    try checkFingerprint(of: Schema(versionedSchema: PulseSchemaV3.self), against: "schema-v3")
}

@Test func v3OnlyAddsTheM4Fields() {
    let v2 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV2.self)))
    let v3 = Set(SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV3.self)))
    #expect(v2.subtracting(v3).isEmpty)
    let added = v3.subtracting(v2).compactMap { $0.split(separator: ":").first.map(String.init) }.filter { !$0.contains(" -> ") }
    #expect(Set(added) == [
        "StoredExerciseSettings.contentExerciseID", "StoredExerciseSettings.createdAt", "StoredExerciseSettings.deletedAt",
        "StoredExerciseSettings.id", "StoredExerciseSettings.incrementKg", "StoredExerciseSettings.updatedAt",
        "StoredExerciseSettings.userExerciseID", "StoredExerciseSettings.warmupSetCount",
        "StoredRoutineDay.createdAt", "StoredRoutineDay.updatedAt",
        "StoredRoutineExercise.createdAt", "StoredRoutineExercise.setTargets", "StoredRoutineExercise.updatedAt",
        "StoredUserExercise.isCompound", "StoredUserExercise.loadKind", "StoredUserExercise.tracksDuration",
        "StoredWorkoutSession.exerciseNotes",
        "StoredWorkoutSet.createdAt", "StoredWorkoutSet.durationSeconds", "StoredWorkoutSet.updatedAt"
    ])
}

@Test func fingerprintNamesTheInverseOfEachRelationship() {
    let lines = SchemaFingerprint.lines(Schema(versionedSchema: PulseSchemaV2.self))
    #expect(lines.contains { $0.hasPrefix("StoredProgram.days -> StoredRoutineDay") && $0.contains("inverse: program") })
    #expect(lines.contains { $0.hasPrefix("StoredRoutineDay.program -> StoredProgram") && $0.contains("inverse: days") })
    #expect(lines.contains { $0.hasPrefix("StoredWorkoutSession.sets -> StoredWorkoutSet") && $0.contains("inverse: session") })
}

@Test func fingerprintListsAttributeOptions() {
    let lines = SchemaFingerprint.lines(Schema([FingerprintProbe.self]))
    #expect(lines.contains { $0.hasPrefix("FingerprintProbe.blob:") && $0.contains("externalStorage") })
}

/// Compare l'empreinte au fichier de référence, ou l'écrit à côté des sources avec `PULSE_WRITE_SCHEMA_FIXTURES=1`.
private func checkFingerprint(of schema: Schema, against name: String, filePath: String = #filePath) throws {
    let contents = SchemaFingerprint.fileContents(schema)
    if ProcessInfo.processInfo.environment["PULSE_WRITE_SCHEMA_FIXTURES"] == "1" {
        let directory = URL(fileURLWithPath: filePath).deletingLastPathComponent().appending(path: "Fixtures", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try contents.write(to: directory.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
        return
    }
    guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures") else {
        Issue.record("Fichier de référence \(name).txt introuvable. \(drift)")
        return
    }
    let expected = try String(contentsOf: url, encoding: .utf8)
    #expect(contents == expected, Comment(rawValue: drift))
}
