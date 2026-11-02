@testable import PulseServices
import Testing

struct CSVReaderTests {
    @Test func quotesCommasAndNewlinesInsideQuotedFields() {
        let text = "a,\"b,\"\"c\"\"\nd\",e\r\nf,,\"\"\n"
        #expect(CSVReader.records(text) == [["a", "b,\"c\"\nd", "e"], ["f", "", ""]])
    }

    @Test func aQuoteInsideAnUnquotedFieldIsKeptLiterally() {
        #expect(CSVReader.records("a\"b,c\"d\n") == [["a\"b", "c\"d"]])
    }

    @Test func blankLinesAndTheByteOrderMarkAreIgnored() {
        #expect(CSVReader.records("\u{FEFF}a,b\n\n\nc,d\n\n") == [["a", "b"], ["c", "d"]])
    }

    @Test func recordsCarryTheLineWhereTheyStart() {
        let parsed = CSVReader.parse("a\n\"x\ny\"\n\nb\r\nc\rd")
        #expect(parsed.records.map(\.line) == [1, 2, 5, 6, 7])
        #expect(parsed.unterminatedQuoteLine == nil)
    }

    @Test func anUnterminatedQuoteIsReportedAtTheLineOfItsRecord() {
        let parsed = CSVReader.parse("a,b\nc,\"open\nd,e")
        #expect(parsed.unterminatedQuoteLine == 2)
    }
}
