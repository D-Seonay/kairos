import Foundation
import PulseServices
import Testing

struct HevyCSVTests {
    private let calendar = TestClock.calendar
    private let header = HevyCSV.header.map { "\"\($0)\"" }.joined(separator: ",")

    private func rows(_ text: String) throws -> [HevyRow] {
        try HevyCSV.rows(from: Data(text.utf8), calendar: calendar)
    }

    @Test func quotedFieldsWithNewlinesQuotesAndEmojiParse() throws {
        let rows = try rows(HevyFixtures.csv)
        #expect(rows.count == 6)
        #expect(rows[0].title == "Push 🫷🫸")
        #expect(rows[0].description == "Note, avec \"guillemets\"\net retour")
        #expect(rows[2].exerciseNotes == "Siège cran 4 — l’épaule ok")
        #expect(rows[0].weightKg == nil && rows[0].reps == 20 && rows[0].rpe == 6)
        #expect(rows[3].durationSeconds == 600 && rows[3].distanceKm == 1.4)
        #expect(rows[4].supersetID == 0 && rows[4].setType == "failure")
    }

    @Test func emptyFieldsBecomeNil() throws {
        let rows = try rows(HevyFixtures.csv)
        #expect(rows[0].exerciseNotes == nil && rows[0].supersetID == nil && rows[0].distanceKm == nil)
        #expect(rows[4].description == nil && rows[4].exerciseNotes == nil)
        #expect(rows[5].rpe == nil)
        #expect(rows[1].weightKg == 60 && rows[1].rpe == 7.5 && rows[2].weightKg == 72.5)
    }

    @Test func datesAreReadInTheCalendarTimeZone() throws {
        let rows = try rows(HevyFixtures.csv)
        #expect(rows[0].startedAt == TestClock.date("2026-10-26T07:00") && rows[0].endedAt == TestClock.date("2026-10-26T08:06"))
        #expect(rows[4].startedAt == TestClock.date("2026-10-27T07:17") && rows[4].endedAt == TestClock.date("2026-10-27T07:59"))
    }

    @Test func aFileWithoutTheHevyHeaderIsRejected() {
        #expect(throws: HevyImportError.notHevyExport) { try HevyCSV.rows(from: Data("a,b\n1,2\n".utf8), calendar: calendar) }
        let missingRPE = HevyCSV.header.dropLast().map { "\"\($0)\"" }.joined(separator: ",")
        #expect(throws: HevyImportError.notHevyExport) { try rows(missingRPE + "\n") }
    }

    @Test func aHeaderOnlyFileIsEmpty() {
        #expect(throws: HevyImportError.empty) { try rows(header + "\n") }
        #expect(throws: HevyImportError.empty) { try rows("") }
    }

    @Test func columnsMayComeInAnyOrderAndExtraColumnsAreIgnored() throws {
        let columns = HevyCSV.header.reversed() + ["extra"]
        let values: [String: String] = [
            "title": "Legs", "start_time": "2 Nov 2026, 10:00", "end_time": "2 Nov 2026, 11:00", "description": "",
            "exercise_title": "Squat", "superset_id": "", "exercise_notes": "", "set_index": "0", "set_type": "normal",
            "weight_kg": "100", "reps": "5", "distance_km": "", "duration_seconds": "", "rpe": "8", "extra": "x"
        ]
        let line = columns.map { "\"\(values[$0] ?? "")\"" }.joined(separator: ",")
        let rows = try rows(columns.joined(separator: ",") + "\n" + line + "\n")
        #expect(rows.count == 1)
        #expect(rows[0].exerciseTitle == "Squat" && rows[0].weightKg == 100 && rows[0].reps == 5 && rows[0].rpe == 8)
        #expect(rows[0].startedAt == TestClock.date("2026-11-02T10:00"))
    }

    @Test func byteOrderMarkAndWindowsLineEndingsAreSupported() throws {
        let line = "\"Pull\",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\",\"a\r\nb\",\"Curl\",,\"\",0,\"normal\",20,10,,,\r\n"
        let rows = try rows("\u{FEFF}" + header + "\r\n" + line + line)
        #expect(rows.count == 2)
        #expect(rows[0].description == "a\r\nb" && rows[0].exerciseTitle == "Curl")
    }

    @Test func unquotedFieldsAndMissingFinalNewlineAreSupported() throws {
        let rows = try rows(header + "\nPull,\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\",,Curl,,,0,normal,20,10,,,")
        #expect(rows.count == 1)
        #expect(rows[0].title == "Pull" && rows[0].description == nil && rows[0].setType == "normal" && rows[0].weightKg == 20)
    }

    @Test func anInvalidDateReportsItsFileLine() {
        let good = "\"Pull\",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\",\"a\nb\",\"Curl\",,\"\",0,\"normal\",20,10,,,"
        let bad = "\"Pull\",\"31 foo 2026, 07:17\",\"27 Oct 2026, 07:59\",\"\",\"Curl\",,\"\",0,\"normal\",20,10,,,"
        #expect(throws: HevyImportError.invalidDate(line: 4)) { try rows([header, good, bad].joined(separator: "\n")) }
    }

    private func setLine(setIndex: String = "0", weight: String = "20", reps: String = "10", extra: String = "") -> String {
        "\"Pull\",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\",\"\",\"Curl\",,\"\",\(setIndex),\"normal\",\(weight),\(reps),,,\(extra)"
    }

    @Test func malformedNumbersFailTheRow() throws {
        let read = try rows([header, setLine(), setLine(weight: "\"72,5\"")].joined(separator: "\n"))
        #expect(read[1].weightKg == 72.5)
        let bad = [setLine(reps: "12.0"), setLine(setIndex: "x"), setLine(weight: "-5"), setLine(weight: "1e3"),
                   setLine(weight: "nan"), setLine(reps: "-1"), setLine(extra: "x"), setLine(weight: "\"1,234.5\"")]
        for text in bad {
            #expect(throws: HevyImportError.invalidRow(line: 3)) { try rows([header, setLine(), text].joined(separator: "\n")) }
        }
    }

    @Test func invalidNumbersInSupersetAndDurationFailTheRow() {
        let superset = line("A", "1 Nov 2026, 10:00", "Curl", superset: "a")
        #expect(throws: HevyImportError.invalidRow(line: 2)) { try rows([header, superset].joined(separator: "\n")) }
        let duration = "\"A\",\"1 Nov 2026, 10:00\",\"1 Nov 2026, 10:00\",\"\",\"Run\",,\"\",0,\"normal\",,,,1.5,"
        #expect(throws: HevyImportError.invalidRow(line: 2)) { try rows([header, duration].joined(separator: "\n")) }
    }

    @Test func recordsWithTheWrongFieldCountFail() {
        let short = "\"Pull\",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\""
        let long = setLine(extra: ",x")
        #expect(throws: HevyImportError.invalidRow(line: 3)) { try rows([header, setLine(), short].joined(separator: "\n")) }
        #expect(throws: HevyImportError.invalidRow(line: 2)) { try rows([header, long, setLine()].joined(separator: "\n")) }
    }

    @Test func anUnterminatedQuoteFails() {
        let open = "\"Pull\",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\",\"never closed\n" + setLine()
        #expect(throws: HevyImportError.invalidRow(line: 3)) { try rows([header, setLine(), open].joined(separator: "\n")) }
    }

    @Test func aBlankLineInTheMiddleIsSkippedAndLinesStayAccurate() {
        let bad = setLine(reps: "x")
        #expect(throws: HevyImportError.invalidRow(line: 5)) { try rows([header, setLine(), "", "", bad].joined(separator: "\n")) }
        #expect((try? rows([header, setLine(), "", setLine()].joined(separator: "\n")).count) == 2)
    }

    @Test func textIsKeptAsWrittenAndNumbersTolerateSpaces() throws {
        let rows = try rows(header + "\n\" Pull \",\"27 Oct 2026, 07:17\",\"27 Oct 2026, 07:59\",\" note\n\",Curl,,,0,normal, 20 , 10,,,")
        #expect(rows[0].title == " Pull " && rows[0].description == " note\n" && rows[0].weightKg == 20 && rows[0].reps == 10)
    }

    @Test func rowsGroupIntoChronologicalWorkoutsAndBlocks() throws {
        let workouts = HevyWorkouts.group(try rows(HevyFixtures.csv))
        #expect(workouts.map(\.title) == ["Push 🫷🫸", "Pull"])
        #expect(workouts[0].exercises.map(\.name) == ["Développé Couché (Barre)", "Écarté (Machine)", "Tapis de Course"])
        #expect(workouts[0].exercises[0].sets.count == 2)
        #expect(workouts[0].description == "Note, avec \"guillemets\"\net retour" && workouts[1].description == nil)
        #expect(workouts[0].startedAt == TestClock.date("2026-10-26T07:00") && workouts[0].endedAt == TestClock.date("2026-10-26T08:06"))
        #expect(workouts[0].exercises[1].notes == "Siège cran 4 — l’épaule ok" && workouts[0].exercises[0].notes == nil)
    }

    private func line(_ title: String, _ start: String, _ exercise: String, superset: String = "") -> String {
        "\"\(title)\",\"\(start)\",\"\(start)\",\"\",\"\(exercise)\",\(superset),\"\",0,\"normal\",20,10,,,"
    }

    @Test func workoutsAreSortedByStartAndSplitOnTitleOrTimes() throws {
        let text = [header,
                    line("B", "2 Nov 2026, 10:00", "Curl"),
                    line("A", "1 Nov 2026, 10:00", "Curl"),
                    line("A", "3 Nov 2026, 10:00", "Curl"),
                    line("C", "2 Nov 2026, 10:00", "Curl")].joined(separator: "\n")
        let workouts = HevyWorkouts.group(try rows(text))
        #expect(workouts.map(\.title) == ["A", "B", "C", "A"])
    }

    @Test func anExerciseSeparatedByAnotherStartsANewBlock() throws {
        let text = [header,
                    line("A", "1 Nov 2026, 10:00", "Curl", superset: "2"),
                    line("A", "1 Nov 2026, 10:00", "Curl", superset: "2"),
                    line("A", "1 Nov 2026, 10:00", "Squat"),
                    line("A", "1 Nov 2026, 10:00", "Curl")].joined(separator: "\n")
        let exercises = try #require(HevyWorkouts.group(try rows(text)).first).exercises
        #expect(exercises.map(\.name) == ["Curl", "Squat", "Curl"])
        #expect(exercises.map(\.sets.count) == [2, 1, 1])
        #expect(exercises.map(\.supersetID) == [2, nil, nil])
    }

    @Test func noRowsMakeNoWorkout() {
        #expect(HevyWorkouts.group([]).isEmpty)
    }
}
