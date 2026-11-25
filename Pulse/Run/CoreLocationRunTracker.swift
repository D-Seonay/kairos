import CoreLocation
import Foundation
import PulseDomain

/// La localisation de la course au-dessus de CoreLocation (spec V2a) : les mises à jour en direct réglées pour le sport, et une
/// session d'arrière-plan gardée pendant le suivi, pour que la course continue écran verrouillé avec l'autorisation « lorsque
/// l'app est active ». Les points partent tels quels : le filtre de précision et de vitesse est celui de `RunTrackBuilder`.
actor CoreLocationRunTracker: RunLocationTracking {
    private var updates: Task<Void, Never>?
    private var background: CLBackgroundActivitySession?
    private var continuation: AsyncStream<RunTrackPoint>.Continuation?

    func authorization() async -> RunLocationAuthorization {
        await LocationPermission.shared.state()
    }

    /// Service de localisation coupé dans les réglages : la demande n'aurait jamais de réponse, la course part sans position. La
    /// lecture se fait ici, hors du fil principal, qu'elle peut bloquer.
    func requestAuthorization() async -> RunLocationAuthorization {
        guard CLLocationManager.locationServicesEnabled() else { return .denied }
        return await LocationPermission.shared.request()
    }

    func isAccuracyReduced() async -> Bool {
        await LocationPermission.shared.isAccuracyReduced()
    }

    /// Remplace un suivi déjà démarré : le flux précédent se termine.
    func start() async -> AsyncStream<RunTrackPoint> {
        let session = await MainActor.run { CLBackgroundActivitySession() }
        stopUpdates()
        let (stream, continuation) = AsyncStream.makeStream(of: RunTrackPoint.self)
        self.continuation = continuation
        background = session
        updates = Task.detached {
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard !Task.isCancelled else { break }
                    // Une mise à jour sans position dit seulement l'état du service (refus, position indisponible).
                    guard let location = update.location else { continue }
                    continuation.yield(Self.point(from: location))
                }
            } catch {}
            continuation.finish()
        }
        return stream
    }

    func stop() async {
        stopUpdates()
    }

    private func stopUpdates() {
        updates?.cancel()
        updates = nil
        continuation?.finish()
        continuation = nil
        background?.invalidate()
        background = nil
    }

    /// Une précision verticale négative dit que l'altitude n'est pas connue.
    static func point(from location: CLLocation) -> RunTrackPoint {
        let hasAltitude = location.verticalAccuracy >= 0
        return RunTrackPoint(timestamp: location.timestamp, latitude: location.coordinate.latitude,
                             longitude: location.coordinate.longitude, altitude: hasAltitude ? location.altitude : nil,
                             horizontalAccuracy: location.horizontalAccuracy,
                             verticalAccuracy: hasAltitude ? location.verticalAccuracy : nil)
    }
}

/// L'autorisation de localisation, lue et demandée sur le fil principal, où vit le `CLLocationManager` et son délégué. La
/// demande attend la réponse de l'utilisateur.
@MainActor
private final class LocationPermission: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermission()

    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<RunLocationAuthorization, Never>] = []

    override private init() {
        super.init()
        manager.delegate = self
    }

    func state() -> RunLocationAuthorization {
        Self.authorization(manager.authorizationStatus)
    }

    /// « Position exacte » coupée pour Pulse dans les réglages : seule une position approximative est livrée.
    func isAccuracyReduced() -> Bool {
        manager.accuracyAuthorization == .reducedAccuracy
    }

    func request() async -> RunLocationAuthorization {
        guard manager.authorizationStatus == .notDetermined else { return state() }
        // Sans texte d'explication, le système ne montre jamais la demande : elle n'aurait pas de réponse.
        guard Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil else { return .denied }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            if waiters.count == 1 { manager.requestWhenInUseAuthorization() }
        }
    }

    /// Appelé à la création du gestionnaire puis à chaque changement : seule une réponse réveille la demande en attente.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            let state = state()
            guard state != .notDetermined, !waiters.isEmpty else { return }
            let answered = waiters
            waiters = []
            for waiter in answered { waiter.resume(returning: state) }
        }
    }

    static func authorization(_ status: CLAuthorizationStatus) -> RunLocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}
