import Foundation
@testable import PulsePersistence
import Testing

/// Un rapport MetricKit réduit, au format de `MXDiagnosticPayload.jsonRepresentation()`.
private func payload(crashes: Int = 0, hangs: [String] = [], launches: [String] = [], cpu: Int = 0) -> Data {
    let metadata: [String: Any] = [
        "appVersion": "1.0.4", "appBuildVersion": "7", "osVersion": "iPhone OS 26.1 (23B85)", "deviceType": "iPhone17,1"
    ]
    var crash = metadata
    crash["terminationReason"] = "Namespace SIGNAL, Code 0xb"
    crash["signal"] = 11
    let root: [String: Any] = [
        "timeStampBegin": "2026-11-24 09:30:00",
        "timeStampEnd": "2026-11-25 09:29:00",
        "crashDiagnostics": Array(repeating: ["callStackTree": [:], "diagnosticMetaData": crash], count: crashes),
        "hangDiagnostics": hangs.map { duration -> [String: Any] in
            var hang = metadata
            hang["hangDuration"] = duration
            return ["callStackTree": [:], "diagnosticMetaData": hang]
        },
        "appLaunchDiagnostics": launches.map { duration -> [String: Any] in
            var launch = metadata
            launch["launchDuration"] = duration
            return ["callStackTree": [:], "diagnosticMetaData": launch]
        },
        "cpuExceptionDiagnostics": Array(repeating: ["diagnosticMetaData": metadata], count: cpu)
    ]
    return (try? JSONSerialization.data(withJSONObject: root)) ?? Data()
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("pulse-diagnostics-\(UUID().uuidString)", isDirectory: true)
}

/// Une horloge qui avance d'une seconde à chaque lecture, à partir du 25 novembre 2026 à 9 h UTC.
private final class SteppingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_795_597_200)

    func next() -> Date {
        lock.lock()
        defer { lock.unlock() }
        current += 1
        return current
    }
}

@Suite struct DiagnosticReportSummaryTests {
    @Test func countsEachKindAndReadsTheMetadata() throws {
        let summary = try #require(DiagnosticReportSummary(json: payload(crashes: 2, hangs: ["3.5 sec", "12 sec"],
                                                                         launches: ["8000 ms"], cpu: 1)))
        #expect(summary.crashes == 2)
        #expect(summary.hangs == 2)
        #expect(summary.slowLaunches == 1)
        #expect(summary.otherExceptions == 1)
        #expect(summary.total == 6)
        #expect(summary.appVersion == "1.0.4 (7)")
        #expect(summary.osVersion == "iPhone OS 26.1 (23B85)")
        #expect(summary.crashReason == "Namespace SIGNAL, Code 0xb")
        #expect(summary.longestHangSeconds == 12)
        #expect(summary.longestLaunchSeconds == 8)
        #expect(summary.periodEnd != nil)
    }

    @Test func anEmptyObjectIsAnEmptyReport() throws {
        let summary = try #require(DiagnosticReportSummary(json: Data("{}".utf8)))
        #expect(summary.total == 0)
        #expect(summary.appVersion == nil)
        #expect(summary.periodEnd == nil)
    }

    @Test func bytesThatAreNotAJSONObjectAreRejected() {
        #expect(DiagnosticReportSummary(json: Data("pas du json".utf8)) == nil)
        #expect(DiagnosticReportSummary(json: Data("[1, 2]".utf8)) == nil)
    }

    @Test func aCrashWithoutReasonFallsBackToItsSignal() throws {
        let json = Data(#"{"crashDiagnostics":[{"diagnosticMetaData":{"signal":6}}]}"#.utf8)
        let summary = try #require(DiagnosticReportSummary(json: json))
        #expect(summary.crashReason == "Signal 6")
        #expect(summary.appVersion == nil)
    }

    @Test func durationsAreReadInSeconds() {
        #expect(DiagnosticReportSummary.seconds("3.5 sec") == 3.5)
        #expect(DiagnosticReportSummary.seconds("250 ms") == 0.25)
        #expect(DiagnosticReportSummary.seconds("2 min") == 120)
        #expect(DiagnosticReportSummary.seconds("3 furlongs") == nil)
        #expect(DiagnosticReportSummary.seconds("vite") == nil)
    }
}

@Suite struct DiagnosticReportStoreTests {
    @Test func aSavedReportIsListedWithItsSummary() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticReportStore(directory: directory)

        let json = payload(crashes: 1)
        let saved = try #require(try await store.save(json))
        let reports = await store.reports()

        #expect(reports == [saved])
        #expect(saved.summary.crashes == 1)
        #expect(saved.fileURL.lastPathComponent.hasPrefix("pulse-diagnostic-"))
        #expect(try Data(contentsOf: saved.fileURL) == DiagnosticReportSanitizer.sanitized(json))
    }

    @Test func onlyTheNewestReportsAreKept() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = SteppingClock()
        let store = DiagnosticReportStore(directory: directory, limit: 3, now: { clock.next() })

        var saved: [DiagnosticReport] = []
        for count in 1...5 {
            saved.append(try #require(try await store.save(payload(hangs: Array(repeating: "1 sec", count: count)))))
        }
        let reports = await store.reports()

        #expect(reports.map(\.summary.hangs) == [5, 4, 3])
        #expect(reports.map(\.id) == saved.suffix(3).reversed().map(\.id))
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.count == 3)
    }

    /// Au-delà de la limite, un plantage reste plus longtemps qu'un blocage ou un lancement lent plus récent.
    @Test func crashesAreKeptBeforeHangsAndSlowLaunches() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = SteppingClock()
        let store = DiagnosticReportStore(directory: directory, limit: 3, now: { clock.next() })

        try await store.save(payload(crashes: 1))
        try await store.save(payload(crashes: 2))
        try await store.save(payload(hangs: ["2 sec"]))
        try await store.save(payload(launches: ["6 sec"]))
        try await store.save(payload(hangs: ["4 sec"]))
        let reports = await store.reports()

        #expect(reports.map(\.summary.crashes) == [0, 2, 1])
        #expect(reports.first?.summary.longestHangSeconds == 4)
    }

    @Test func freeTextIsRemovedBeforeWriting() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticReportStore(directory: directory)
        let json = Data(#"""
            {"crashDiagnostics":[{"callStackTree":{"callStacks":[]},"diagnosticMetaData":{"signal":6,"appVersion":"1.0.4",
            "objectiveCexceptionReason":{"composedMessage":"Clé inconnue : Créatine 5 g","formatString":"Clé inconnue : %@",
            "arguments":["Créatine 5 g"],"exceptionName":"NSInvalidArgumentException"}}}]}
            """#.utf8)

        let saved = try #require(try await store.save(json))
        let written = try String(contentsOf: saved.fileURL, encoding: .utf8)

        #expect(!written.contains("Créatine"))
        #expect(!written.contains("composedMessage"))
        #expect(!written.contains("arguments"))
        #expect(written.contains("NSInvalidArgumentException"))
        #expect(written.contains("formatString"))
        #expect(saved.summary.crashes == 1)
        #expect(saved.summary.appVersion == "1.0.4")
    }

    @Test func anEmptyOrUnreadableReportIsNotWritten() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticReportStore(directory: directory)

        #expect(try await store.save(Data("{}".utf8)) == nil)
        #expect(try await store.save(Data("pas du json".utf8)) == nil)
        #expect(await store.reports().isEmpty)
    }

    @Test func theFolderIsExcludedFromBackups() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticReportStore(directory: directory)

        try await store.save(payload(crashes: 1))

        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func removeAllLeavesOtherFilesAlone() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticReportStore(directory: directory)
        try await store.save(payload(crashes: 1))
        try await store.save(payload(launches: ["5 sec"]))
        let other = directory.appendingPathComponent("autre.json")
        try Data("{}".utf8).write(to: other)

        try await store.removeAll()

        #expect(await store.reports().isEmpty)
        #expect(FileManager.default.fileExists(atPath: other.path))
    }

    @Test func theReceptionTimeIsReadBackFromTheFileName() throws {
        let date = Date(timeIntervalSince1970: 1_795_597_200.125)
        let url = URL(fileURLWithPath: "/tmp/pulse-diagnostic-\(DiagnosticReportStore.stamp(date))-abcd1234.json")
        let read = try #require(DiagnosticReportStore.receivedAt(of: url))
        #expect(abs(read.timeIntervalSince(date)) < 0.001)
        #expect(DiagnosticReportStore.receivedAt(of: URL(fileURLWithPath: "/tmp/autre.json")) == nil)
    }
}
