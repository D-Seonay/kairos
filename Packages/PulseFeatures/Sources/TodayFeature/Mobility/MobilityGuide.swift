import Foundation

/// Les cinq consignes de la séance de mobilité, dans l'ordre.
enum MobilityGuide {
    static var steps: [String] {
        [
            String(localized: "Hanches : 10 cercles lents de chaque côté, puis 1 min en fente basse par jambe.", bundle: .module),
            String(localized: "Chevilles : 10 flexions du genou vers l'avant par cheville, talon au sol.", bundle: .module),
            String(localized: "Colonne thoracique : 10 rotations à quatre pattes de chaque côté.", bundle: .module),
            String(localized: "Épaules : 10 passages de bâton ou d'élastique devant puis derrière.", bundle: .module),
            String(localized: "Respiration : 2 min allongé, inspire 4 s, expire 6 s.", bundle: .module)
        ]
    }
}
