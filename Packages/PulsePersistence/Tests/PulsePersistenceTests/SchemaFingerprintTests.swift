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
