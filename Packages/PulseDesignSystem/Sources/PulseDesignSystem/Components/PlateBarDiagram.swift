import SwiftUI

/// Une barre chargée, vue de face : la poignée au centre et, sur chaque manchon, les disques du plus lourd (contre la butée)
/// au plus léger. La hauteur d'un disque suit son poids, comme en salle. Muette pour VoiceOver : le texte à côté dit les disques.
public struct PlateBarDiagram: View {
    private let perSide: [Double]

    /// `perSide` : les disques d'un côté, du plus lourd au plus léger.
    public init(perSide: [Double]) {
        self.perSide = perSide
    }

    public var body: some View {
        Canvas { context, size in
            let ink = context.resolve(GraphicsContext.Shading.color(PulsePalette.ink))
            let midY = size.height / 2
            let center = size.width / 2
            // La poignée fine au centre, les manchons plus épais de chaque côté, là où vont les disques.
            let grip = size.width * 0.12
            context.fill(Path(CGRect(x: center - grip, y: midY - 2, width: 2 * grip, height: 4)),
                         with: .color(PulsePalette.ink.opacity(0.35)))
            context.fill(Path(roundedRect: CGRect(x: 0, y: midY - 4, width: center - grip, height: 8), cornerRadius: 2),
                         with: .color(PulsePalette.ink.opacity(0.3)))
            context.fill(Path(roundedRect: CGRect(x: center + grip, y: midY - 4, width: center - grip, height: 8), cornerRadius: 2),
                         with: .color(PulsePalette.ink.opacity(0.3)))
            for side in [-1.0, 1.0] {
                let collar = center + side * size.width * 0.12
                context.fill(Path(roundedRect: CGRect(x: collar - 3, y: midY - 12, width: 6, height: 24), cornerRadius: 2),
                             with: ink)
                var edge = collar + side * 4
                for plate in perSide {
                    let height = size.height * Self.heightShare(plate)
                    let width = Self.width(plate)
                    let x = side > 0 ? edge : edge - width
                    let rect = CGRect(x: x, y: midY - height / 2, width: width, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: min(3, width / 3)), with: ink)
                    // Un liseré clair entre deux disques, pour qu'on les compte.
                    context.stroke(Path(roundedRect: rect, cornerRadius: min(3, width / 3)),
                                   with: .color(PulsePalette.page.opacity(0.7)), lineWidth: 1)
                    edge += side * (width + 1)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// La hauteur d'un disque, en part de la hauteur de la vue : un 25 kg la prend presque toute, un 1,25 kg un tiers.
    static func heightShare(_ plateKg: Double) -> Double {
        switch plateKg {
        case 20...: 0.95
        case 15..<20: 0.82
        case 10..<15: 0.68
        case 5..<10: 0.5
        case 2.5..<5: 0.4
        default: 0.32
        }
    }

    /// L'épaisseur d'un disque, en points.
    static func width(_ plateKg: Double) -> Double {
        switch plateKg {
        case 20...: 11
        case 10..<20: 9
        case 5..<10: 7
        default: 5
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        PlateBarDiagram(perSide: [25, 15])
        PlateBarDiagram(perSide: [20, 10, 5, 2.5, 1.25])
        PlateBarDiagram(perSide: [])
    }
    .frame(height: 360)
    .padding()
    .background(PulsePalette.surface)
}
