import CoreGraphics
import PulseDomain
import Testing

@testable import PulseDesignSystem

@Test func everyMuscleHasARegion() {
    for muscle in Muscle.allCases {
        #expect(!muscle.mapRegions.isEmpty)
    }
}

@Test func lowerBodyMappings() {
    #expect(Muscle.glutes.mapRegions == [.gluteal] && Muscle.abductors.mapRegions == [.gluteal])
    #expect(Muscle.lats.mapRegions == [.upperBack] && Muscle.frontDelts.mapRegions == [.frontDeltoid])
}

@Test func regionNamesMatchTheMockup() {
    #expect(MuscleMapRegion.allCases.count == 30)
    #expect(MuscleMapRegion(rawValue: "forearm") == .forearm)
    #expect(MuscleMapRegion(rawValue: "hamstring") == .hamstring)
}

@Test func overlayRegionsAreExactlyTheTransparentFallbacks() {
    let overlays: Set<MuscleMapRegion> = [
        .frontDeltoid, .hipFlexors, .innerQuad, .lowerAbs, .lowerChest, .lowerTrapezius, .outerQuad,
        .rearDeltoid, .rhomboids, .serratus, .upperAbs, .upperChest, .upperTrapezius
    ]
    #expect(Set(MuscleMapRegion.allCases.filter(\.isOverlay)) == overlays)
    let bases: Set<MuscleMapRegion> = [
        .abs, .adductors, .biceps, .calves, .chest, .deltoids, .forearm, .gluteal, .hamstring, .lowerBack,
        .obliques, .quadriceps, .rotatorCuff, .tibialis, .trapezius, .triceps, .upperBack
    ]
    #expect(Set(MuscleMapRegion.allCases.filter { !$0.isOverlay }) == bases)
}

@Test func artworkParsesAndCoversMappedRegions() {
    let art = MuscleMapArtwork.bundled
    let drawn = Set(art.regions(.front, figure: .female).keys).union(art.regions(.back, figure: .female).keys)
    #expect(Set(Muscle.allCases.flatMap(\.mapRegions)).isSubset(of: drawn))
    #expect(art.license.contains("MIT"))
}

@Test(arguments: MuscleMapFigure.allCases)
func eachFigureDrawsEveryRegion(_ figure: MuscleMapFigure) {
    let art = MuscleMapArtwork.bundled
    let drawn = Set(art.regions(.front, figure: figure).keys).union(art.regions(.back, figure: figure).keys)
    #expect(Set(MuscleMapRegion.allCases) == drawn)
    #expect(!art.body(.front, figure: figure).isEmpty && !art.body(.back, figure: figure).isEmpty)
}

@Test func viewBoxesKeepTheirOrigin() {
    let art = MuscleMapArtwork.bundled
    #expect(art.viewBox(.front, figure: .female) == CGRect(x: 0, y: 0, width: 650, height: 1450))
    #expect(art.viewBox(.back, figure: .female) == CGRect(x: 823, y: 0, width: 650, height: 1450))
}

@Test func maleViewBoxesKeepTheirOrigin() {
    let art = MuscleMapArtwork.bundled
    #expect(art.viewBox(.front, figure: .male) == CGRect(x: 0, y: 95, width: 727, height: 1280))
    #expect(art.viewBox(.back, figure: .male) == CGRect(x: 718, y: 95, width: 727, height: 1280))
}

@Test(arguments: MuscleMapFigure.allCases)
func backPathsLieInsideTheBackViewBox(_ figure: MuscleMapFigure) {
    let art = MuscleMapArtwork.bundled
    let box = art.viewBox(.back, figure: figure).insetBy(dx: -2, dy: -2)
    for path in art.body(.back, figure: figure) {
        #expect(box.contains(path.boundingRect))
    }
}

/// Un tracé illisible serait avalé par `try?` : on compte ce qui a été lu.
@Test func everyPathParses() {
    let art = MuscleMapArtwork.bundled
    func count(_ side: MuscleMapSide, _ figure: MuscleMapFigure) -> Int {
        art.layers(side, figure: figure).reduce(0) { $0 + $1.paths.count }
    }
    #expect(count(.front, .female) == 124 && count(.back, .female) == 78)
    #expect(count(.front, .male) == 123 && count(.back, .male) == 78)
}

@Test func layersKeepTheDocumentDrawOrder() {
    let front = MuscleMapArtwork.bundled.layers(.front, figure: .female).map(\.region)
    #expect(Array(front.prefix(4)) == [nil, .trapezius, nil, .deltoids])
    let back = MuscleMapArtwork.bundled.layers(.back, figure: .female).map(\.region)
    #expect(Array(back.prefix(4)) == [nil, nil, .trapezius, .deltoids])
}

@Test func layerCountMatchesTheSvgGroups() {
    let art = MuscleMapArtwork.bundled
    #expect(art.layers(.front, figure: .female).count == 29)
    #expect(art.layers(.back, figure: .female).count == 20)
    #expect(art.layers(.front, figure: .male).count == 29)
    #expect(art.layers(.back, figure: .male).count == 21)
    for figure in MuscleMapFigure.allCases {
        for side in [MuscleMapSide.front, .back] {
            let layers = art.layers(side, figure: figure)
            let layered = layers.reduce(0) { $0 + $1.paths.count }
            let flat = art.body(side, figure: figure).count + art.regions(side, figure: figure).values.reduce(0) { $0 + $1.count }
            #expect(layered == flat)
            #expect(layers.filter { $0.region == nil }.flatMap(\.paths).count == art.body(side, figure: figure).count)
        }
    }
}

/// Les surimpressions se dessinent par-dessus les régions de base : aucune ne passe avant la dernière région de base.
@Test(arguments: MuscleMapFigure.allCases)
func overlaysAreDrawnLast(_ figure: MuscleMapFigure) {
    for side in [MuscleMapSide.front, .back] {
        let overlays = MuscleMapArtwork.bundled.layers(side, figure: figure).map { $0.region?.isOverlay ?? false }
        let firstOverlay = overlays.firstIndex(of: true) ?? overlays.count
        #expect(!overlays[firstOverlay...].contains(false), "\(figure) \(side)")
    }
}

@Test func intensityQuarters() {
    let levels = MuscleIntensity.levels(weights: [.chest: 4, .triceps: 3, .frontDelts: 1.5, .abs: 0])
    #expect(levels == [.chest: 4, .triceps: 3, .frontDeltoid: 2])
}

@Test func sharedRegionTakesTheHighestLevel() {
    #expect(MuscleIntensity.levels(weights: [.glutes: 4, .abductors: 1])[.gluteal] == 4)
}

@Test func tinyWeightStillLightsLevelOne() {
    #expect(MuscleIntensity.levels(weights: [.chest: 100, .biceps: 0.1])[.biceps] == 1)
}

@Test func noWeightMeansNoLevel() {
    #expect(MuscleIntensity.levels(weights: [:]).isEmpty)
    #expect(MuscleIntensity.levels(weights: [.chest: 0]).isEmpty)
}

@Test func levelColorsMixTheAccentWithTheOffGrey() {
    let accent = PulseRGBA(hex: 0xF59E0B)
    let off = PulsePalette.muscleOffRGBA
    #expect(MuscleIntensity.color(level: 4, accent: accent) == accent)
    let half = MuscleIntensity.color(level: 2, accent: accent)
    #expect(abs(half.red - (accent.red * 0.7 + off.red * 0.3)) < 1e-9)
    #expect(abs(half.blue - (accent.blue * 0.7 + off.blue * 0.3)) < 1e-9)
    let first = MuscleIntensity.color(level: 1, accent: accent)
    #expect(abs(first.green - (accent.green * 0.5 + off.green * 0.5)) < 1e-9)
}

@Test func levelOneStaysDistinguishableFromTheUnlitBody() {
    let off = PulsePalette.muscleOffLightRGBA
    for theme in Theme.allCases {
        let first = MuscleIntensity.color(level: 1, accent: PulsePalette.accent(for: theme).accent.light, off: off)
        #expect(Contrast.ratio(first, on: off) >= 3, "\(theme)")
    }
}

@Test func muscleIntensitiesFollowTheQuarterRule() {
    let intensities = MuscleIntensity.byMuscle(weights: [.chest: 4, .triceps: 3, .frontDelts: 1.5, .abs: 0])
    #expect(intensities == [.chest: .maximum, .triceps: .strong, .frontDelts: .moderate])
    #expect(MuscleIntensity.byMuscle(weights: [.chest: 100, .biceps: 0.1])[.biceps] == .light)
    #expect(MuscleIntensity.byMuscle(weights: [:]).isEmpty)
}

@Test func summaryListsTheStrongestMusclesFirst() {
    let text = MuscleMapSummary.text(levels: [.triceps: .moderate, .chest: .strong])
    #expect(text == "Pectoraux, intensité forte. Triceps, intensité moyenne.")
}

@Test func summarySortsTiesByName() {
    let text = MuscleMapSummary.text(levels: [.quads: .strong, .biceps: .strong, .abs: .strong, .calves: .light])
    #expect(text == "Abdominaux, intensité forte. Biceps, intensité forte. Quadriceps, intensité forte. Mollets, intensité légère.")
}

@Test func summaryNamesEveryMuscleInFrench() {
    for muscle in Muscle.allCases {
        let text = MuscleMapSummary.text(levels: [muscle: .light])
        #expect(text.hasSuffix(", intensité légère."))
        #expect(!text.contains("_") && text.first?.isUppercase == true)
        #expect(text.lowercased() != text)
    }
    #expect(MuscleMapSummary.text(levels: [.frontDelts: .maximum]) == "Deltoïdes antérieurs, intensité très forte.")
}

@Test func emptySummaryReadsAsNoMuscle() {
    #expect(MuscleMapSummary.text(levels: [:]) == "Aucun muscle travaillé")
}

@Test func accentSharesRaiseTheLowLevels() {
    #expect(MuscleIntensity.accentShares == [0.5, 0.7, 0.85, 1])
}

/// Le dessin ramène la `viewBox` de chaque silhouette sur la toile : le dos (x = 823 ou 718) et le corps d'homme (y = 95)
/// doivent tomber dans le cadre, pas à côté.
@Test(arguments: MuscleMapFigure.allCases)
func drawingFitsEverySilhouetteInItsCanvas(_ figure: MuscleMapFigure) {
    let art = MuscleMapArtwork.bundled
    for side in [MuscleMapSide.front, .back] {
        let box = art.viewBox(side, figure: figure)
        let size = CGSize(width: box.width / 10, height: box.height / 10)
        let transform = MuscleMapView.transform(for: box, in: size)
        let origin = CGPoint(x: box.minX, y: box.minY).applying(transform)
        let corner = CGPoint(x: box.maxX, y: box.maxY).applying(transform)
        #expect(abs(origin.x) < 1e-9 && abs(origin.y) < 1e-9, "\(figure) \(side)")
        #expect(abs(corner.x - size.width) < 1e-9 && abs(corner.y - size.height) < 1e-9, "\(figure) \(side)")
        let canvas = CGRect(origin: .zero, size: size).insetBy(dx: -0.5, dy: -0.5)
        for path in art.layers(side, figure: figure).flatMap(\.paths) {
            #expect(canvas.contains(path.applying(transform).boundingRect), "\(figure) \(side)")
        }
    }
}
