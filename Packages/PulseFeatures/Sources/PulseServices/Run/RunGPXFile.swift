import Foundation
import PulseDomain

/// Écrit le GPX d'une course dans un fichier temporaire, prêt pour la feuille de partage. Le dossier ne garde que le dernier
/// fichier écrit : un tracé (donnée de localisation) ne s'y accumule pas, et iOS vide de lui-même le dossier temporaire.
public enum RunGPXFile {
    /// Le sous-dossier du dossier temporaire où vivent les fichiers à partager.
    static let folderName = "PulseGPX"

    /// « Pulse-course-2026-11-25-0730.gpx », à l'heure locale du départ.
    public static func fileName(startedAt: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startedAt)
        let date = String(format: "%04d-%02d-%02d-%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                          parts.hour ?? 0, parts.minute ?? 0)
        return "Pulse-course-\(date).gpx"
    }

    /// Écrit le GPX de `track` sous `directory` (le dossier temporaire par défaut) et rend son adresse. Les fichiers déjà
    /// écrits dans le même dossier sont effacés d'abord.
    public static func write(_ track: RunTrack, session: WorkoutSession, calendar: Calendar,
                             directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let folder = directory.appending(path: folderName, directoryHint: .isDirectory)
        let files = FileManager.default
        if files.fileExists(atPath: folder.path(percentEncoded: false)) {
            try files.removeItem(at: folder)
        }
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName(startedAt: session.startedAt, calendar: calendar))
        let document = RunGPX.document(points: track.points, name: session.title, startedAt: session.startedAt)
        try Data(document.utf8).write(to: url, options: .atomic)
        return url
    }
}
