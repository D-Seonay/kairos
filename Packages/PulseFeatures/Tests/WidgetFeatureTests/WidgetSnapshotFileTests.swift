import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

struct WidgetSnapshotFileTests {
    private func temporaryFile() -> WidgetSnapshotFile {
        WidgetSnapshotFile(url: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(WidgetSnapshotFile.fileName))
    }

    @Test func fileRoundTrip() throws {
        let file = temporaryFile()
        let snapshot = WidgetSample.snapshot()
        #expect(try file.write(snapshot))
        #expect(file.read() == snapshot)
        #expect(try !file.write(snapshot))
        #expect(try file.write(WidgetSample.snapshot(isEstimated: true)))
        try file.delete()
        #expect(file.read() == nil)
    }

    @Test func missingFileIsNoSnapshot() {
        #expect(temporaryFile().read() == nil)
    }

    @Test func unreadableFileIsNoSnapshot() throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{".utf8).write(to: file.url)
        #expect(file.read() == nil)
    }

    @Test func deletingAnAbsentFileIsHarmless() throws {
        try temporaryFile().delete()
    }

    @Test func fileHoldsNothingButTheSnapshotFields() throws {
        let file = temporaryFile()
        try file.write(WidgetSample.snapshot())
        let text = try String(contentsOf: file.url, encoding: .utf8)
        #expect(text.contains("\"score\":58"))
        #expect(text.contains("\"sessionTitle\":\"Push\""))
        #expect(text.contains("2026-11-01T23:00:00Z"))
    }

    @Test func appGroupFileIsNamedAfterTheSnapshot() {
        #expect(WidgetSnapshotFile.appGroupIdentifier == "group.fr.seonay.pulse")
        #expect(WidgetSnapshotFile.fileName == "recovery-widget.json")
    }
}
