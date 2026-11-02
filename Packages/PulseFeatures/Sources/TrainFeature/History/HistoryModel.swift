import Foundation
import Observation
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// Une séance de l'historique, résumée pour sa ligne.
public struct HistoryLine: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var date: Date
    public var durationMinutes: Int?
    /// Les séries hors échauffement.
    public var workingSets: Int
    public var tonnageKg: Double
    public var recordCount: Int
    /// Vrai pour une séance importée de Hevy.
    public var isImported: Bool
    public var isAbandoned: Bool

    public init(id: UUID, title: String, date: Date, durationMinutes: Int?, workingSets: Int, tonnageKg: Double, recordCount: Int,
                isImported: Bool, isAbandoned: Bool) {
        self.id = id
        self.title = title
        self.date = date
        self.durationMinutes = durationMinutes
        self.workingSets = workingSets
        self.tonnageKg = tonnageKg
        self.recordCount = recordCount
        self.isImported = isImported
        self.isAbandoned = isAbandoned
    }
}

/// Les séances d'un mois, de la plus récente à la plus ancienne.
public struct HistoryMonth: Identifiable, Equatable, Sendable {
    /// « octobre 2026 ».
    public var title: String
    public var sessions: [HistoryLine]

    public init(title: String, sessions: [HistoryLine]) {
        self.title = title
        self.sessions = sessions
    }

    public var id: String { title }
}

/// L'historique des séances de musculation, terminées ou abandonnées, regroupées par mois (spec M4 §12), séances Pulse et séances
/// importées de Hevy mêlées.
@MainActor
@Observable
public final class HistoryModel {
    public private(set) var months: [HistoryMonth] = []
    /// Vrai une fois l'historique lu, qu'il soit vide ou non.
    public private(set) var hasLoaded = false
    public private(set) var hasImportedSessions = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let environment: TrainEnvironment

    public init(environment: TrainEnvironment) {
        self.environment = environment
    }

    /// Relit les séances. Si la lecture échoue, l'écran garde son dernier état et affiche une erreur.
    public func load() async {
        do {
            let sessions = try await environment.workouts.sessions(from: .distantPast, to: .distantFuture)
            let userExercises = try await environment.userExercises.all(includeArchived: true)
            let directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
            let shown = sessions
                .filter { $0.kind == .strength && ($0.status == .completed || $0.status == .abandoned) }
                .sorted { $0.startedAt > $1.startedAt }
            months = grouped(shown.map { line(for: $0, directory: directory) })
            hasImportedSessions = shown.contains { $0.source == .hevy }
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire ton historique.", bundle: .module)
        }
        hasLoaded = true
    }

    /// Supprime toutes les séances importées de Hevy, recalcule les records, relit l'historique et rend le nombre de séances
    /// supprimées. La vue demande confirmation avant.
    public func removeImported() async throws -> Int {
        let removed = try await environment.importer.removeImportedSessions()
        await load()
        return removed
    }

    /// « lun. 27 oct. », dans le calendrier de l'environnement.
    public func dateText(_ date: Date) -> String {
        environment.text(of: date) { $0.weekday(.abbreviated).day().month(.abbreviated) }
    }

    // MARK: - Interne

    private func line(for session: WorkoutSession, directory: ExerciseDirectory) -> HistoryLine {
        let working = session.sets.filter { $0.setType != .warmup }
        return HistoryLine(
            id: session.id, title: session.title, date: session.startedAt, durationMinutes: Self.durationMinutes(of: session),
            workingSets: working.count, tonnageKg: SessionTonnage.kilograms(of: session.sets, loadKind: directory.loadKind(of:)),
            recordCount: working.filter(\.isPersonalRecord).count, isImported: session.source == .hevy,
            isAbandoned: session.status == .abandoned)
    }

    static func durationMinutes(of session: WorkoutSession) -> Int? {
        if let minutes = session.durationMinutes { return Int(minutes.rounded()) }
        return session.endedAt.map { Int(($0.timeIntervalSince(session.startedAt) / 60).rounded()) }
    }

    /// Regroupe les lignes déjà triées par mois, dans le même ordre.
    private func grouped(_ lines: [HistoryLine]) -> [HistoryMonth] {
        let calendar = environment.calendar
        var result: [HistoryMonth] = []
        var currentMonth: DateComponents?
        for line in lines {
            let month = calendar.dateComponents([.year, .month], from: line.date)
            if month == currentMonth, !result.isEmpty {
                result[result.count - 1].sessions.append(line)
            } else {
                currentMonth = month
                result.append(HistoryMonth(title: monthTitle(of: line.date), sessions: [line]))
            }
        }
        return result
    }

    /// « octobre 2026 », avec le calendrier de l'environnement et la locale française.
    private func monthTitle(of date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = environment.calendar
        formatter.timeZone = environment.calendar.timeZone
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        return formatter.string(from: date)
    }
}
