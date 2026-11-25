import Foundation

/// Le tracé d'une course au format GPX 1.1, pour l'ouvrir dans Strava, Garmin Connect ou tout autre outil. Pur calcul : rien
/// n'est envoyé nulle part, l'appelant écrit le texte dans un fichier que l'utilisateur partage s'il le veut.
///
/// Chaque point porte sa position, son horodatage (UTC) et son altitude quand elle est connue. Pulse ne garde pas la fréquence
/// cardiaque point par point (seulement la moyenne de la séance) : le fichier n'a donc pas d'extension de FC.
public enum RunGPX {
    /// L'application qui a produit le fichier, dans l'attribut `creator`.
    public static let creator = "Pulse"

    /// Le document GPX complet d'une course. `name` nomme la course ; `startedAt` date le fichier (balise `metadata`). Un tracé
    /// vide donne un segment vide, toujours valide.
    public static func document(points: [RunTrackPoint], name: String, startedAt: Date) -> String {
        let title = escaped(name)
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<gpx version="1.1" creator="\#(creator)" xmlns="http://www.topografix.com/GPX/1/1" "#
                + #"xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" "#
                + #"xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">"#,
            "  <metadata>",
            "    <name>\(title)</name>",
            "    <time>\(timestamp(startedAt))</time>",
            "  </metadata>",
            "  <trk>",
            "    <name>\(title)</name>",
            "    <type>running</type>",
            "    <trkseg>"
        ]
        lines.reserveCapacity(lines.count + points.count + 4)
        for point in points {
            lines.append("      " + trackPoint(point))
        }
        lines += ["    </trkseg>", "  </trk>", "</gpx>", ""]
        return lines.joined(separator: "\n")
    }

    /// La plus grande longitude écrite à 7 décimales, sous la borne exclue de 180.
    static let maxLongitude = 179.9999999

    /// Un `trkpt` sur une ligne : l'altitude (`ele`) précède l'heure (`time`), dans l'ordre qu'impose le schéma.
    static func trackPoint(_ point: RunTrackPoint) -> String {
        // Le schéma borne la latitude à [-90, 90] et la longitude à [-180, 180[ : 179,99999996 arrondi écrirait 180.0000000.
        let latitude = String(format: "%.7f", min(max(point.latitude, -90), 90))
        let longitude = String(format: "%.7f", min(max(point.longitude, -180), maxLongitude))
        var children = ""
        if let altitude = point.altitude, altitude.isFinite {
            children += "<ele>\(String(format: "%.1f", altitude))</ele>"
        }
        children += "<time>\(timestamp(point.timestamp))</time>"
        return #"<trkpt lat="\#(latitude)" lon="\#(longitude)">\#(children)</trkpt>"#
    }

    /// « 2026-11-25T06:30:00Z » : ISO 8601 en UTC, comme l'attend le format.
    static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .gmt))
    }

    /// Le texte rendu sûr dans un élément ou un attribut XML.
    static func escaped(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            // Les caractères de contrôle deviennent des espaces ; U+FFFE et U+FFFF, interdits en XML 1.0, disparaissent.
            case _ where character.unicodeScalars.allSatisfy({ $0.value < 0x20 }): result += " "
            case _ where character.unicodeScalars.contains(where: { $0.value == 0xFFFE || $0.value == 0xFFFF }): continue
            default: result.append(character)
            }
        }
        return result
    }
}
