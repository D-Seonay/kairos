import CoreGraphics
import Foundation
import PulseDomain
import SwiftUI

public enum MuscleMapSide: Sendable {
    case front
    case back
}

/// Un groupe `<g>` du SVG : `region == nil` pour le corps. Les calques sont rangés dans l'ordre de dessin du document.
public struct MuscleMapLayer: Sendable {
    public let region: MuscleMapRegion?
    public let paths: [Path]
}

/// Les silhouettes MuscleMap de femme et d'homme (MIT, Melih Colpan), lues dans `musclemap.json` et parsées une seule fois.
public struct MuscleMapArtwork: Sendable {
    fileprivate struct Silhouette: Sendable {
        let viewBox: CGRect
        let body: [Path]
        let regions: [MuscleMapRegion: [Path]]
        let layers: [MuscleMapLayer]
    }

    public static let bundled = load()

    public let license: String
    private let female: (front: Silhouette, back: Silhouette)
    private let male: (front: Silhouette, back: Silhouette)

    public func body(_ side: MuscleMapSide, figure: MuscleMapFigure) -> [Path] { silhouette(side, figure).body }

    public func regions(_ side: MuscleMapSide, figure: MuscleMapFigure) -> [MuscleMapRegion: [Path]] {
        silhouette(side, figure).regions
    }

    /// Les groupes du SVG dans l'ordre du document : c'est l'ordre dans lequel il faut les dessiner.
    public func layers(_ side: MuscleMapSide, figure: MuscleMapFigure) -> [MuscleMapLayer] { silhouette(side, figure).layers }

    public func viewBox(_ side: MuscleMapSide, figure: MuscleMapFigure) -> CGRect { silhouette(side, figure).viewBox }

    private func silhouette(_ side: MuscleMapSide, _ figure: MuscleMapFigure) -> Silhouette {
        let pair = switch figure {
        case .female: female
        case .male: male
        }
        return switch side {
        case .front: pair.front
        case .back: pair.back
        }
    }
}

private extension MuscleMapArtwork {
    struct SideFile: Decodable {
        let viewBox: [Double]
        let body: [String]
        let regions: [String: [String]]
        let layers: [LayerFile]
    }

    struct LayerFile: Decodable {
        let name: String
        let paths: [String]
    }

    struct FigureFile: Decodable {
        let front: SideFile
        let back: SideFile
    }

    struct File: Decodable {
        let license: String
        let female: FigureFile
        let male: FigureFile
    }

    /// Une ressource illisible donne une carte vide plutôt qu'un crash ; les tests de couverture la signalent.
    static func load() -> MuscleMapArtwork {
        guard
            let url = Bundle.module.url(forResource: "musclemap", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            return MuscleMapArtwork(license: "", female: (.empty, .empty), male: (.empty, .empty))
        }
        return MuscleMapArtwork(
            license: file.license,
            female: (Silhouette(file.female.front), Silhouette(file.female.back)),
            male: (Silhouette(file.male.front), Silhouette(file.male.back))
        )
    }
}

fileprivate extension MuscleMapArtwork.Silhouette {
    static let empty = MuscleMapArtwork.Silhouette(viewBox: .zero, body: [], regions: [:], layers: [])

    init(_ file: MuscleMapArtwork.SideFile) {
        let box = file.viewBox
        let rect = box.count == 4 ? CGRect(x: box[0], y: box[1], width: box[2], height: box[3]) : .zero
        var regions: [MuscleMapRegion: [Path]] = [:]
        for (name, data) in file.regions {
            if let region = MuscleMapRegion(rawValue: name) {
                regions[region] = data.compactMap { try? SVGPathParser.parse($0) }
            }
        }
        let layers = file.layers.compactMap { layer -> MuscleMapLayer? in
            let region = MuscleMapRegion(rawValue: layer.name)
            guard region != nil || layer.name == "body" else { return nil }
            return MuscleMapLayer(region: region, paths: layer.paths.compactMap { try? SVGPathParser.parse($0) })
        }
        self.init(
            viewBox: rect, body: file.body.compactMap { try? SVGPathParser.parse($0) }, regions: regions, layers: layers
        )
    }
}
