import Foundation
@testable import PulseDomain
import Testing

@Suite("Export GPX d'une course")
struct RunGPXTests {
    /// Un petit tracé de fixture : quatre points à 10 s d'écart, l'altitude connue sauf sur le troisième.
    private static let start = Date(timeIntervalSince1970: 1_795_000_000)
    private static let points: [RunTrackPoint] = [
        RunTrackPoint(timestamp: start, latitude: 48.8566, longitude: 2.3522, altitude: 35.04, horizontalAccuracy: 5),
        RunTrackPoint(timestamp: start.addingTimeInterval(10), latitude: 48.85672, longitude: 2.35245, altitude: 35.6,
                      horizontalAccuracy: 5),
        RunTrackPoint(timestamp: start.addingTimeInterval(20), latitude: 48.85685, longitude: 2.3527, altitude: nil,
                      horizontalAccuracy: 6),
        RunTrackPoint(timestamp: start.addingTimeInterval(30), latitude: -0.0000012, longitude: -179.9999999, altitude: -2,
                      horizontalAccuracy: 4)
    ]

    @Test("le document est du XML bien formé au format GPX 1.1, avec un point par point du tracé")
    func documentIsWellFormedGPX11() throws {
        let gpx = RunGPX.document(points: Self.points, name: "Sortie du matin", startedAt: Self.start)
        let parsed = try #require(GPXProbe.parse(gpx))

        #expect(parsed.root == "gpx")
        #expect(parsed.rootAttributes["version"] == "1.1")
        #expect(parsed.rootAttributes["creator"] == "Pulse")
        #expect(parsed.rootAttributes["xmlns"] == "http://www.topografix.com/GPX/1/1")
        #expect(parsed.trackPoints.count == 4)
        #expect(parsed.texts["type"] == ["running"])
        #expect(parsed.texts["name"] == ["Sortie du matin", "Sortie du matin"])
        #expect(gpx.hasPrefix(#"<?xml version="1.0" encoding="UTF-8"?>"#))
    }

    @Test("chaque point porte sa position, son heure UTC et son altitude seulement quand elle est connue")
    func pointsCarryPositionTimeAndOptionalElevation() throws {
        let gpx = RunGPX.document(points: Self.points, name: "Course", startedAt: Self.start)
        let parsed = try #require(GPXProbe.parse(gpx))

        #expect(parsed.trackPoints[0] == ["lat": "48.8566000", "lon": "2.3522000"])
        #expect(parsed.trackPoints[3] == ["lat": "-0.0000012", "lon": "-179.9999999"])
        // L'altitude du troisième point est inconnue : trois `ele` pour quatre points.
        #expect(parsed.texts["ele"] == ["35.0", "35.6", "-2.0"])
        #expect(parsed.texts["time"] == ["2026-11-18T11:06:40Z", "2026-11-18T11:06:40Z", "2026-11-18T11:06:50Z",
                                         "2026-11-18T11:07:00Z", "2026-11-18T11:07:10Z"])
    }

    @Test("le nom de la course est échappé et se relit tel quel")
    func nameIsEscaped() throws {
        let name = #"5 km <seuil> & "côtes" d'Ivry"#
        let gpx = RunGPX.document(points: Self.points, name: name, startedAt: Self.start)
        let parsed = try #require(GPXProbe.parse(gpx))
        #expect(parsed.texts["name"] == [name, name])
        #expect(!gpx.contains("<seuil>"))
    }

    @Test("les coordonnées restent dans les bornes du schéma, même arrondies")
    func coordinatesStayWithinSchemaBounds() {
        let point = RunTrackPoint(timestamp: Self.start, latitude: 90.00000004, longitude: 179.99999996, horizontalAccuracy: 5)
        #expect(RunGPX.trackPoint(point).hasPrefix(#"<trkpt lat="90.0000000" lon="179.9999999">"#))
        let west = RunTrackPoint(timestamp: Self.start, latitude: -90.5, longitude: -180.00000004, horizontalAccuracy: 5)
        #expect(RunGPX.trackPoint(west).hasPrefix(#"<trkpt lat="-90.0000000" lon="-180.0000000">"#))
    }

    @Test("les caractères interdits en XML 1.0 ne passent pas dans le nom")
    func forbiddenCharactersLeaveTheName() throws {
        let gpx = RunGPX.document(points: [], name: "Sortie\u{FFFE}\u{FFFF}\u{0001}du soir", startedAt: Self.start)
        let parsed = try #require(GPXProbe.parse(gpx))
        #expect(parsed.texts["name"] == ["Sortie du soir", "Sortie du soir"])
    }

    @Test("un tracé vide donne un segment vide, toujours valide")
    func emptyTrackStaysValid() throws {
        let parsed = try #require(GPXProbe.parse(RunGPX.document(points: [], name: "Course", startedAt: Self.start)))
        #expect(parsed.root == "gpx")
        #expect(parsed.trackPoints.isEmpty)
        #expect(parsed.elements.contains("trkseg"))
    }

    @Test("dans un point, l'altitude précède l'heure, comme l'impose le schéma")
    func elevationComesBeforeTime() {
        let line = RunGPX.trackPoint(Self.points[0])
        #expect(line == #"<trkpt lat="48.8566000" lon="2.3522000"><ele>35.0</ele><time>2026-11-18T11:06:40Z</time></trkpt>"#)
    }
}

/// Relit un document GPX avec `XMLParser` : un document mal formé rend `nil`.
private final class GPXProbe: NSObject, XMLParserDelegate {
    struct Result {
        var root = ""
        var rootAttributes: [String: String] = [:]
        var elements: [String] = []
        var trackPoints: [[String: String]] = []
        /// Le texte de chaque élément feuille, par nom, dans l'ordre du document.
        var texts: [String: [String]] = [:]
    }

    private var result = Result()
    private var text = ""

    static func parse(_ document: String) -> Result? {
        let probe = GPXProbe()
        let parser = XMLParser(data: Data(document.utf8))
        parser.delegate = probe
        return parser.parse() ? probe.result : nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if result.elements.isEmpty {
            result.root = elementName
            result.rootAttributes = attributes
        }
        result.elements.append(elementName)
        if elementName == "trkpt" { result.trackPoints.append(attributes) }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if ["name", "type", "ele", "time"].contains(elementName) {
            result.texts[elementName, default: []].append(text)
        }
        text = ""
    }
}
