import CoreGraphics
import Foundation
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

/// Les silhouettes MuscleMap (MIT, Melih Colpan), lues dans `musclemap.json` et parsées une seule fois.
public struct MuscleMapArtwork: Sendable {
    fileprivate struct Silhouette: Sendable {
        let viewBox: CGRect
        let body: [Path]
        let regions: [MuscleMapRegion: [Path]]
        let layers: [MuscleMapLayer]
    }

    public static let bundled = load()

    public let license: String
    private let front: Silhouette
    private let back: Silhouette

    public func body(_ side: MuscleMapSide) -> [Path] { silhouette(side).body }

    public func regions(_ side: MuscleMapSide) -> [MuscleMapRegion: [Path]] { silhouette(side).regions }

    /// Les groupes du SVG dans l'ordre du document : c'est l'ordre dans lequel il faut les dessiner.
    public func layers(_ side: MuscleMapSide) -> [MuscleMapLayer] { silhouette(side).layers }

    public func viewBox(_ side: MuscleMapSide) -> CGRect { silhouette(side).viewBox }

    private func silhouette(_ side: MuscleMapSide) -> Silhouette {
        switch side {
        case .front: front
        case .back: back
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

    struct File: Decodable {
        let license: String
        let front: SideFile
        let back: SideFile
    }

    /// Une ressource illisible donne une carte vide plutôt qu'un crash ; les tests de couverture la signalent.
    static func load() -> MuscleMapArtwork {
        guard
            let url = Bundle.module.url(forResource: "musclemap", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            return MuscleMapArtwork(license: "", front: .empty, back: .empty)
        }
        return MuscleMapArtwork(license: file.license, front: Silhouette(file.front), back: Silhouette(file.back))
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
