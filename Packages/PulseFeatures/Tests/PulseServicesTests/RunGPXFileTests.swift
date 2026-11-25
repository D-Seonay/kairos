import Foundation
import PulseDomain
@testable import PulseServices
import Testing

@Suite("Fichier GPX d'une course")
struct RunGPXFileTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendar
    }()

    private static func run(at start: Date) -> (WorkoutSession, RunTrack) {
        let session = WorkoutSession(startedAt: start, kind: .run, source: .pulse, status: .completed, title: "Footing",
                                     createdAt: start, updatedAt: start)
        let points = (0..<3).map {
            RunTrackPoint(timestamp: start.addingTimeInterval(Double($0) * 10), latitude: 48.85 + Double($0) * 0.0001,
                          longitude: 2.35, altitude: 30, horizontalAccuracy: 5)
        }
        return (session, RunTrack(id: session.id, points: points, splits: [], createdAt: start, updatedAt: start))
    }

    @Test("le nom du fichier suit la date et l'heure locales du départ")
    func fileNameFollowsLocalStart() {
        // 2026-11-25 06:30 UTC, 07:30 à Paris.
        let start = Date(timeIntervalSince1970: 1_795_588_200)
        #expect(RunGPXFile.fileName(startedAt: start, calendar: Self.calendar) == "Pulse-course-2026-11-25-0730.gpx")
    }

    @Test("le fichier écrit contient le GPX du tracé, et remplace celui écrit avant")
    func writesTheTrackAndKeepsOnlyTheLatestFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (first, firstTrack) = Self.run(at: Date(timeIntervalSince1970: 1_795_588_200))
        let (second, secondTrack) = Self.run(at: Date(timeIntervalSince1970: 1_795_674_600))

        let firstURL = try RunGPXFile.write(firstTrack, session: first, calendar: Self.calendar, directory: directory)
        let secondURL = try RunGPXFile.write(secondTrack, session: second, calendar: Self.calendar, directory: directory)

        let contents = try String(contentsOf: secondURL, encoding: .utf8)
        #expect(contents == RunGPX.document(points: secondTrack.points, name: "Footing", startedAt: second.startedAt))
        #expect(!FileManager.default.fileExists(atPath: firstURL.path(percentEncoded: false)))
        let folder = secondURL.deletingLastPathComponent()
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)) == [secondURL.lastPathComponent])
    }
}
