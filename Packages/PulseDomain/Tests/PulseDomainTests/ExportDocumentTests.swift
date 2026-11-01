// swiftlint:disable force_unwrapping
import Foundation
@testable import PulseDomain
import Testing

@Test func exportDatesUseLocalOffset() throws {
    let paris = TimeZone(identifier: "Europe/Paris")!
    let date = Date(timeIntervalSince1970: 1_794_726_753)      // 2026-11-15T08:12:33+01:00
    let doc = ExportDocument.empty(exportedAt: date, appVersion: "1.0 (1)", schemaVersion: 1, contentVersion: "1.0.0", locale: "fr_FR")
    let text = String(bytes: try ExportCoding.encoder(timeZone: paris).encode(doc), encoding: .utf8)!
    #expect(text.contains(#""exportedAt" : "2026-11-15T08:12:33+01:00""#))
    #expect(text.contains(#""format" : "pulse-export""#))
    #expect(text.contains(#""formatVersion" : 1"#))
    #expect(text.contains(#""weight" : "kg""#))
    let back = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(text.utf8))
    #expect(back == doc)
    #expect(back.programs.isEmpty && back.profile == nil && back.contentExercises.isEmpty)
}

@Test func exportDecoderAcceptsOtherOffsets() throws {
    let decoder = ExportCoding.decoder()
    let date = try decoder.decode(Date.self, from: Data(#""2026-11-15T07:12:33Z""#.utf8))
    #expect(date == Date(timeIntervalSince1970: 1_794_726_753))
}
// swiftlint:enable force_unwrapping
