import Foundation
import PulseDomain

/// Écrit le GPX d'une course dans un fichier temporaire, prêt pour la feuille de partage. Le dossier ne garde que le dernier
/// fichier écrit, rangé sous l'identifiant de sa séance : un tracé (donnée de localisation) ne s'y accumule pas. Le fichier est
/// retiré quand on quitte le détail, quand la course est supprimée, et avec tout le dossier par « Tout supprimer ».
public enum RunGPXFile {
    /// Le dossier des fichiers à partager, dans le dossier temporaire de l'app.
    public static var directory: URL {
        FileManager.default.temporaryDirectory.appending(path: "PulseGPX", directoryHint: .isDirectory)
    }

    /// « Pulse-course-2026-11-25-0730.gpx », à l'heure locale du départ.
    public static func fileName(startedAt: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startedAt)
        let date = String(format: "%04d-%02d-%02d-%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                          parts.hour ?? 0, parts.minute ?? 0)
        return "Pulse-course-\(date).gpx"
    }

    /// Écrit le GPX de `track` dans `directory` et rend son adresse. Ce que le dossier contenait est effacé d'abord. Appelé hors
    /// du fil principal : l'écriture d'un long tracé ne fige pas l'écran.
    public static func write(_ track: RunTrack, session: WorkoutSession, calendar: Calendar,
                             directory: URL = RunGPXFile.directory) throws -> URL {
        removeAll(directory: directory)
        let folder = directory.appending(path: session.id.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName(startedAt: session.startedAt, calendar: calendar))
        let document = RunGPX.document(points: track.points, name: session.title, startedAt: session.startedAt)
        try Data(document.utf8).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Retire le fichier de la course `sessionID`, s'il existe.
    public static func remove(sessionID: UUID, directory: URL = RunGPXFile.directory) {
        try? FileManager.default.removeItem(at: directory.appending(path: sessionID.uuidString, directoryHint: .isDirectory))
    }

    /// Vide le dossier des fichiers à partager.
    public static func removeAll(directory: URL = RunGPXFile.directory) {
        try? FileManager.default.removeItem(at: directory)
    }
}
