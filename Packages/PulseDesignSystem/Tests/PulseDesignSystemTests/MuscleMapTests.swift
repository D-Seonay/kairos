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
    let drawn = Set(art.regions(.front).keys).union(art.regions(.back).keys)
    #expect(Set(Muscle.allCases.flatMap(\.mapRegions)).isSubset(of: drawn))
    #expect(Set(MuscleMapRegion.allCases) == drawn)
    #expect(!art.body(.front).isEmpty && !art.body(.back).isEmpty)
    #expect(art.license.contains("MIT"))
}

@Test func viewBoxesKeepTheirOrigin() {
    let art = MuscleMapArtwork.bundled
    #expect(art.viewBox(.front) == CGRect(x: 0, y: 0, width: 650, height: 1450))
    #expect(art.viewBox(.back) == CGRect(x: 823, y: 0, width: 650, height: 1450))
}

@Test func backPathsLieInsideTheBackViewBox() {
    let art = MuscleMapArtwork.bundled
    let box = art.viewBox(.back).insetBy(dx: -2, dy: -2)
    for path in art.body(.back) {
        #expect(box.contains(path.boundingRect))
    }
}

@Test func layersKeepTheDocumentDrawOrder() {
    let front = MuscleMapArtwork.bundled.layers(.front).map(\.region)
    #expect(Array(front.prefix(4)) == [nil, .trapezius, nil, .deltoids])
    let back = MuscleMapArtwork.bundled.layers(.back).map(\.region)
    #expect(Array(back.prefix(4)) == [nil, nil, .trapezius, .deltoids])
}

@Test func layerCountMatchesTheSvgGroups() {
    let art = MuscleMapArtwork.bundled
    #expect(art.layers(.front).count == 29)
    #expect(art.layers(.back).count == 20)
    for side in [MuscleMapSide.front, .back] {
        let layered = art.layers(side).reduce(0) { $0 + $1.paths.count }
        let flat = art.body(side).count + art.regions(side).values.reduce(0) { $0 + $1.count }
        #expect(layered == flat)
        #expect(art.layers(side).filter { $0.region == nil }.flatMap(\.paths).count == art.body(side).count)
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
    #expect(abs(half.red - (accent.red * 0.56 + off.red * 0.44)) < 1e-9)
    #expect(abs(half.blue - (accent.blue * 0.56 + off.blue * 0.44)) < 1e-9)
    let first = MuscleIntensity.color(level: 1, accent: accent)
    #expect(abs(first.green - (accent.green * 0.32 + off.green * 0.68)) < 1e-9)
}
