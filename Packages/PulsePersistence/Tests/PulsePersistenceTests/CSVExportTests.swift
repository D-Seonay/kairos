import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func csvArchiveContainsEveryTableAndRoundTripsQuotedNote() async throws {   // Review Focus 2
    let box = try ModelContainerBox()
    try await SampleDataSeeder(container: box.container).seed(now: Fixed.t0)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory)
    let zip = try await exporter.exportCSVArchive()
    #expect(zip.pathExtension == "zip" && zip.lastPathComponent.hasSuffix("-csv.zip"))
    let size = try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int ?? 0
    #expect(size > 100)
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    let files = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
    #expect(files == Set(StoreTable.exported.map { $0.fileName + ".csv" }).union(["README.txt"]))
    let sets = try String(contentsOf: folder.appendingPathComponent("workout_sets.csv"), encoding: .utf8)
    #expect(sets.split(separator: "\n").count == 10)
    let sessions = try String(contentsOf: folder.appendingPathComponent("workout_sessions.csv"), encoding: .utf8)
    #expect(sessions.contains("\"Dos ok, \"\"lourd\"\" aujourd'hui\""))
}

@Test func csvExportOfEmptyStoreHasHeadersOnly() async throws {
    let box = try ModelContainerBox()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory)
    _ = try await exporter.exportCSVArchive()
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    for table in StoreTable.exported {
        let text = try String(contentsOf: folder.appendingPathComponent(table.fileName + ".csv"), encoding: .utf8)
        #expect(text.split(separator: "\n").count == 1, Comment(rawValue: table.rawValue))
    }
}
