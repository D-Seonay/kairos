import Foundation

public enum RunLocationAuthorization: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}

/// La localisation pendant la course, derrière un protocole pour les tests. Implémenté par l'app au-dessus de CoreLocation.
public protocol RunLocationTracking: Sendable {
    func authorization() async -> RunLocationAuthorization
    /// Montre la demande système si elle n'a jamais été faite, puis rend l'état.
    func requestAuthorization() async -> RunLocationAuthorization
    /// Démarre le suivi ; le flux rend chaque point livré, jusqu'à `stop()`.
    func start() async -> AsyncStream<RunTrackPoint>
    func stop() async
}

/// Doublure : l'état se règle, les points se poussent à la main dans le flux ouvert par `start()`.
public actor StubRunLocationTracker: RunLocationTracking {
    public private(set) var state: RunLocationAuthorization
    private let grantedOnRequest: RunLocationAuthorization
    public private(set) var requestCount = 0
    public private(set) var startCount = 0
    public private(set) var stopCount = 0
    private var continuation: AsyncStream<RunTrackPoint>.Continuation?

    public init(state: RunLocationAuthorization = .authorized, grantedOnRequest: RunLocationAuthorization = .authorized) {
        self.state = state
        self.grantedOnRequest = grantedOnRequest
    }

    public func authorization() async -> RunLocationAuthorization {
        state
    }

    public func requestAuthorization() async -> RunLocationAuthorization {
        requestCount += 1
        if state == .notDetermined { state = grantedOnRequest }
        return state
    }

    public func start() async -> AsyncStream<RunTrackPoint> {
        startCount += 1
        continuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: RunTrackPoint.self)
        self.continuation = continuation
        return stream
    }

    public func stop() async {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    /// Livre un point au flux ouvert ; sans effet si le suivi n'est pas démarré.
    public func push(_ point: RunTrackPoint) {
        continuation?.yield(point)
    }
}

/// Un entraînement de course à écrire dans Apple Santé.
public struct RunWorkoutEntry: Sendable, Equatable {
    public var sessionID: UUID
    public var start: Date
    public var end: Date
    public var pauses: [RunPause]
    /// La distance GPS filtrée, et elle seule ; `nil` sans tracé.
    public var distanceMeters: Double?
    /// Points retenus par le filtre, non simplifiés.
    public var route: [RunTrackPoint]

    public init(sessionID: UUID, start: Date, end: Date, pauses: [RunPause] = [], distanceMeters: Double? = nil,
                route: [RunTrackPoint] = []) {
        self.sessionID = sessionID
        self.start = start
        self.end = end
        self.pauses = pauses
        self.distanceMeters = distanceMeters
        self.route = route
    }
}

/// HealthKit a accepté l'entraînement sans l'écrire tout de suite (iPhone verrouillé) : il l'écrira de lui-même au déverrouillage.
/// L'entraînement ne doit donc pas être écrit une seconde fois.
public struct RunWorkoutWriteDeferred: Error, Equatable {
    public init() {}
}

/// La séance HealthKit de la course, derrière un protocole pour les tests. Implémenté par PulseHealth.
public protocol RunWorkoutRecording: Sendable {
    func writeAccess() async -> HealthWriteAccess
    /// Montre la demande système si elle n'a jamais été faite, puis rend l'état.
    func requestWriteAccess() async -> HealthWriteAccess
    /// Démarre la séance HealthKit ; le flux rend la FC si la séance en livre.
    func start(sessionID: UUID, at date: Date) async throws -> AsyncStream<Double>
    func pause(at date: Date) async
    func resume(at date: Date) async
    /// Termine la séance en cours et écrit l'entraînement ; `nil` s'il n'y a pas de séance vivante. Lance
    /// `RunWorkoutWriteDeferred` si HealthKit écrira l'entraînement plus tard.
    func finish(_ entry: RunWorkoutEntry) async throws -> UUID?
    /// Écrit un entraînement sans séance vivante (course interrompue) ; rend celui déjà écrit pour la même course s'il existe.
    /// Lance `RunWorkoutWriteDeferred` si HealthKit l'écrira plus tard.
    func save(_ entry: RunWorkoutEntry) async throws -> UUID
    /// Supprime l'entraînement écrit par Pulse et son tracé ; sans effet s'il n'existe plus.
    func deleteWorkout(id: UUID) async throws
    func discard() async
    /// Rattache une séance que le système a gardée après un crash ; vrai si elle tourne encore.
    func recoverActiveSession() async -> Bool
}

/// Doublure en mémoire : l'accès se règle, les appels et les entraînements écrits sont gardés.
public actor StubRunWorkoutRecorder: RunWorkoutRecording {
    public private(set) var access: HealthWriteAccess
    private let grantedOnRequest: HealthWriteAccess
    public private(set) var requestCount = 0
    public private(set) var started: [(sessionID: UUID, date: Date)] = []
    public private(set) var pauseDates: [Date] = []
    public private(set) var resumeDates: [Date] = []
    public private(set) var finished: [RunWorkoutEntry] = []
    public private(set) var saved: [UUID: RunWorkoutEntry] = [:]
    public private(set) var deletedWorkouts: [UUID] = []
    public private(set) var discardCount = 0
    /// Les entraînements laissés à HealthKit pour plus tard, par `finish` ou `save`.
    public private(set) var deferred: [RunWorkoutEntry] = []
    /// Vrai entre `start` et `finish` / `discard`, ou après une reprise réussie.
    public private(set) var hasLiveSession: Bool
    private let recoverable: Bool
    private let failsOnStart: Bool
    private let failsOnWrite: Bool
    private let failsOnFinish: Bool
    private let defersWrite: Bool
    private var heartRates: AsyncStream<Double>.Continuation?

    public struct Failure: Error {}

    public init(access: HealthWriteAccess = .authorized, grantedOnRequest: HealthWriteAccess = .authorized,
                hasLiveSession: Bool = false, recoverable: Bool = false, failsOnStart: Bool = false,
                failsOnWrite: Bool = false, failsOnFinish: Bool = false, defersWrite: Bool = false) {
        self.access = access
        self.grantedOnRequest = grantedOnRequest
        self.hasLiveSession = hasLiveSession
        self.recoverable = recoverable
        self.failsOnStart = failsOnStart
        self.failsOnWrite = failsOnWrite
        self.failsOnFinish = failsOnFinish
        self.defersWrite = defersWrite
    }

    public func writeAccess() async -> HealthWriteAccess {
        access
    }

    public func requestWriteAccess() async -> HealthWriteAccess {
        requestCount += 1
        if access == .notDetermined { access = grantedOnRequest }
        return access
    }

    public func start(sessionID: UUID, at date: Date) async throws -> AsyncStream<Double> {
        if failsOnStart { throw Failure() }
        started.append((sessionID, date))
        hasLiveSession = true
        heartRates?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: Double.self)
        heartRates = continuation
        return stream
    }

    public func pause(at date: Date) async {
        pauseDates.append(date)
    }

    public func resume(at date: Date) async {
        resumeDates.append(date)
    }

    public func finish(_ entry: RunWorkoutEntry) async throws -> UUID? {
        guard hasLiveSession else { return nil }
        if failsOnWrite || failsOnFinish { throw Failure() }
        hasLiveSession = false
        heartRates?.finish()
        heartRates = nil
        if defersWrite {
            deferred.append(entry)
            throw RunWorkoutWriteDeferred()
        }
        finished.append(entry)
        return UUID()
    }

    public func save(_ entry: RunWorkoutEntry) async throws -> UUID {
        if failsOnWrite { throw Failure() }
        if defersWrite {
            deferred.append(entry)
            throw RunWorkoutWriteDeferred()
        }
        let id = UUID()
        saved[id] = entry
        return id
    }

    public func deleteWorkout(id: UUID) async throws {
        saved[id] = nil
        deletedWorkouts.append(id)
    }

    public func discard() async {
        discardCount += 1
        hasLiveSession = false
        heartRates?.finish()
        heartRates = nil
    }

    public func recoverActiveSession() async -> Bool {
        if recoverable { hasLiveSession = true }
        return hasLiveSession
    }

    /// La séance vivante s'arrête hors de Pulse (le système l'a terminée) : `finish` ne la trouve plus.
    public func loseLiveSession() {
        hasLiveSession = false
    }

    /// Livre une fréquence cardiaque au flux ouvert ; sans effet sans séance vivante.
    public func pushHeartRate(_ bpm: Double) {
        heartRates?.yield(bpm)
    }
}

/// Les annonces vocales de la course, derrière un protocole pour les tests.
public protocol RunAnnouncing: Sendable {
    func announce(_ text: String) async
}

/// Doublure qui garde les textes annoncés, dans l'ordre.
public actor StubRunAnnouncer: RunAnnouncing {
    public private(set) var announcements: [String] = []

    public init() {}

    public func announce(_ text: String) async {
        announcements.append(text)
    }
}

/// Ce que la Live Activity de course affiche.
public struct RunActivityState: Sendable, Equatable, Codable {
    public var sessionID: UUID
    public var title: String
    /// Début du chronomètre en mouvement ; `nil` en pause.
    public var timerStart: Date?
    /// Durée en mouvement à afficher figée, en pause.
    public var frozenElapsedSeconds: Int
    public var distanceMeters: Double?
    public var averagePaceSecondsPerKm: Int?
    public var isPaused: Bool

    public init(sessionID: UUID, title: String, timerStart: Date? = nil, frozenElapsedSeconds: Int = 0,
                distanceMeters: Double? = nil, averagePaceSecondsPerKm: Int? = nil, isPaused: Bool = false) {
        self.sessionID = sessionID
        self.title = title
        self.timerStart = timerStart
        self.frozenElapsedSeconds = frozenElapsedSeconds
        self.distanceMeters = distanceMeters
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.isPaused = isPaused
    }
}

/// Pilote la Live Activity de la course en cours. Implémenté par l'app au-dessus d'ActivityKit.
public protocol RunActivityControlling: Sendable {
    func start(_ state: RunActivityState) async
    func update(_ state: RunActivityState) async
    func end() async
    /// Termine toutes les Live Activities de course.
    func endAll() async
}

/// Doublure qui garde les états reçus (démarrage puis mises à jour), dans l'ordre, et compte les fins.
public actor StubRunActivityController: RunActivityControlling {
    public private(set) var states: [RunActivityState] = []
    public private(set) var endCount = 0
    public private(set) var endAllCount = 0

    public init() {}

    public func start(_ state: RunActivityState) async {
        states.append(state)
    }

    public func update(_ state: RunActivityState) async {
        states.append(state)
    }

    public func end() async {
        endCount += 1
    }

    public func endAll() async {
        endAllCount += 1
    }
}

/// Le rappel « course oubliée », derrière un protocole pour les tests.
public protocol RunReminderScheduling: Sendable {
    func scheduleForgotten(at date: Date) async
    func cancelForgotten() async
}

/// Doublure qui garde les dates programmées et compte les annulations.
public actor StubRunReminderScheduler: RunReminderScheduling {
    public private(set) var scheduled: [Date] = []
    public private(set) var cancelCount = 0

    public init() {}

    public func scheduleForgotten(at date: Date) async {
        scheduled.append(date)
    }

    public func cancelForgotten() async {
        cancelCount += 1
    }
}
