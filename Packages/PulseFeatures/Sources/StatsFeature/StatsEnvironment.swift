import Foundation
import PulseServices
import TrainFeature

/// Tout ce dont l'onglet Stats a besoin du dehors : le calcul des cinq vues, l'environnement de l'onglet Séance (pour la fiche
/// d'un exercice) et l'horloge.
public struct StatsEnvironment: Sendable {
    public var service: StatsService
    public var train: TrainEnvironment
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(service: StatsService, train: TrainEnvironment, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.service = service
        self.train = train
        self.calendar = calendar
        self.now = now
    }
}

/// Les cinq vues du sélecteur de l'onglet Stats (spec M7 §5).
public enum StatsView: String, CaseIterable, Sendable, Identifiable {
    case load
    case biometry
    case muscles
    case attendance
    case records

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .load: String(localized: "Charge", bundle: .module)
        case .biometry: String(localized: "Biométrie", bundle: .module)
        case .muscles: String(localized: "Muscles", bundle: .module)
        case .attendance: String(localized: "Assiduité", bundle: .module)
        case .records: String(localized: "Records", bundle: .module)
        }
    }
}
