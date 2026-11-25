import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Ce qu'une tranche de barre de sommeil représente : une phase, ou l'ancien découpage à l'encre des barres sans phases.
enum SleepLayerKind: Hashable {
    case stage(SleepStage)
    /// Le profond d'une barre sans phases, à l'encre pleine.
    case deepInk
    /// Le reste d'une barre sans phases, à l'encre claire.
    case otherInk

    /// L'ordre des tranches de bas en haut, et celui de la légende.
    static let order: [SleepLayerKind] = [.stage(.deep), .stage(.core), .stage(.rem), .stage(.asleepUnspecified), .deepInk,
                                          .otherInk]

    var style: Color {
        switch self {
        case let .stage(stage): stage.color
        case .deepInk: StatsInk.full
        case .otherInk: StatsInk.light
        }
    }
}

/// Une tranche d'une barre de sommeil : ce qu'elle représente et ses bornes en heures.
struct SleepLayer: Identifiable, Equatable {
    let kind: SleepLayerKind
    let start: Double
    let end: Double

    var id: SleepLayerKind { kind }
    var style: Color { kind.style }
}

/// Le découpage des barres de sommeil de Stats et la légende qui va avec.
enum SleepChartLayers {
    /// Les tranches d'une barre, de bas en haut, en heures. Une barre à phases s'empile profond, léger, paradoxal, sans phase ;
    /// une barre d'avant les phases garde l'ancien découpage à l'encre : le profond en bas, le reste au-dessus. Une tranche
    /// n'existe que si elle dure au moins une minute une fois arrondie, le seuil des phrases dites de chaque barre : quelques
    /// secondes sans phase ne se dessinent pas et n'entrent pas dans la légende.
    static func layers(of point: SleepPoint) -> [SleepLayer] {
        let total = point.asleepMinutes / 60
        guard point.hasStages else {
            let deep = min(max(point.deepMinutes ?? 0, 0), point.asleepMinutes) / 60
            return [SleepLayer(kind: .deepInk, start: 0, end: deep), SleepLayer(kind: .otherInk, start: deep, end: total)]
                .filter(lastsAMinute)
        }
        let stages: [(SleepStage, Double?)] = [(.deep, point.deepMinutes), (.core, point.coreMinutes), (.rem, point.remMinutes),
                                               (.asleepUnspecified, point.unspecifiedMinutes)]
        var bottom = 0.0
        return stages.compactMap { stage, minutes in
            guard let minutes, minutes.rounded() > 0 else { return nil }
            let top = min(bottom + minutes / 60, total)
            defer { bottom = top }
            let layer = SleepLayer(kind: .stage(stage), start: bottom, end: top)
            return lastsAMinute(layer) ? layer : nil
        }
    }

    /// Vrai si la tranche dure au moins une minute une fois arrondie.
    private static func lastsAMinute(_ layer: SleepLayer) -> Bool {
        ((layer.end - layer.start) * 60).rounded() > 0
    }

    /// La légende nomme exactement les tranches dessinées sur la période affichée : une entrée n'y figure que si au moins une
    /// barre en dessine une tranche non vide, dans l'ordre d'empilement. Une barre à phases qui n'a pas de paradoxal n'ajoute
    /// donc pas « Paradoxal ». Le profond à l'encre se dit « Profond, sans détail » quand des tranches de phase sont aussi
    /// dessinées, pour le distinguer du profond en couleur.
    static func legend(of points: [SleepPoint]) -> [(label: String, style: Color)] {
        let drawn = Set(points.flatMap { layers(of: $0).map(\.kind) })
        let hasStageLayers = drawn.contains { if case .stage = $0 { true } else { false } }
        return SleepLayerKind.order.filter(drawn.contains).map { kind in
            (label(of: kind, besideStages: hasStageLayers), kind.style)
        }
    }

    private static func label(of kind: SleepLayerKind, besideStages: Bool) -> String {
        switch kind {
        case .stage(.asleepUnspecified): String(localized: "Sans phase", bundle: .module)
        case let .stage(stage): stage.displayName
        case .deepInk where besideStages: String(localized: "Profond, sans détail", bundle: .module)
        case .deepInk: String(localized: "Profond", bundle: .module)
        case .otherInk: String(localized: "Autres phases", bundle: .module)
        }
    }
}
