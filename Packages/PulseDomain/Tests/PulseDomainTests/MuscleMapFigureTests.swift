import Foundation
@testable import PulseDomain
import Testing

@Test func figureFollowsTheProfileSex() {
    #expect(MuscleMapFigure(sex: .female) == .female)
    #expect(MuscleMapFigure(sex: .male) == .male)
    #expect(MuscleMapFigure(sex: .unspecified) == .female)
}

private func snapshot(figure: MuscleMapFigure?) -> WidgetSnapshot {
    WidgetSnapshot(day: Date(timeIntervalSince1970: 1_800_000_000), score: 72, category: .optimal, isEstimated: false,
                   sessionTitle: "Push", isLightened: false, muscleMapFigure: figure)
}

private func encoded(_ snapshot: WidgetSnapshot) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(snapshot)
}

private func decoded(_ data: Data) throws -> WidgetSnapshot {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(WidgetSnapshot.self, from: data)
}

/// Le fichier écrit par une version d'avant le choix de silhouette n'a pas la clé.
@Test func snapshotWithoutFigureStillDecodes() throws {
    var object = try #require(try JSONSerialization.jsonObject(with: encoded(snapshot(figure: .male))) as? [String: Any])
    #expect(object.removeValue(forKey: "muscleMapFigure") != nil)
    let old = try decoded(JSONSerialization.data(withJSONObject: object))
    #expect(old.muscleMapFigure == nil)
    #expect(old.sessionTitle == "Push")
}

@Test func snapshotKeepsItsFigure() throws {
    let original = snapshot(figure: .male)
    #expect(try decoded(encoded(original)) == original)
}
