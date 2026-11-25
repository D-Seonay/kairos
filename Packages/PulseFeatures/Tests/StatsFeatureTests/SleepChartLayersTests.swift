import Foundation
import PulseDomain
import PulseServices
@testable import StatsFeature
import Testing

/// Les tranches des barres de sommeil et la légende : elle ne nomme que ce qui est dessiné sur la période.
struct SleepChartLayersTests {
    private static let day = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func point(_ offset: Int, asleep: Double, deep: Double?, core: Double? = nil, rem: Double? = nil,
                       unspecified: Double? = nil) -> SleepPoint {
        SleepPoint(date: Self.day.addingTimeInterval(Double(offset) * 86_400), asleepMinutes: asleep, deepMinutes: deep,
                   coreMinutes: core, remMinutes: rem, unspecifiedMinutes: unspecified)
    }

    private func labels(_ points: [SleepPoint]) -> [String] {
        SleepChartLayers.legend(of: points).map(\.label)
    }

    @Test func stagedBarStacksItsStagesFromTheBottom() {
        let layers = SleepChartLayers.layers(of: point(0, asleep: 480, deep: 60, core: 300, rem: 120))
        #expect(layers.map(\.kind) == [.stage(.deep), .stage(.core), .stage(.rem)])
        #expect(layers.map(\.start) == [0, 1, 6])
        #expect(layers.map(\.end) == [1, 6, 8])
    }

    @Test func unstagedBarKeepsTheInkSplitAndDropsEmptyLayers() {
        #expect(SleepChartLayers.layers(of: point(0, asleep: 420, deep: 60)).map(\.kind) == [.deepInk, .otherInk])
        #expect(SleepChartLayers.layers(of: point(0, asleep: 420, deep: nil)).map(\.kind) == [.otherInk])
        #expect(SleepChartLayers.layers(of: point(0, asleep: 420, deep: 0)).map(\.kind) == [.otherInk])
    }

    @Test func legendOfOnlyStagedBarsNamesTheirStages() {
        #expect(labels([point(0, asleep: 480, deep: 60, core: 300, rem: 120)]) == ["Profond", "Léger", "Paradoxal"])
    }

    /// Une seule barre à phases parmi des barres sans phases : la légende nomme ses phases, puis l'ancien découpage.
    @Test func mixedPeriodNamesBothSplits() {
        let points = [point(0, asleep: 480, deep: 60, core: 300, rem: 120), point(1, asleep: 420, deep: 70)]
        #expect(labels(points) == ["Profond", "Léger", "Paradoxal", "Profond, sans détail", "Autres phases"])
    }

    @Test func legendLeavesOutAStageNoBarDraws() {
        let points = [point(0, asleep: 400, deep: 60, core: 340, rem: 0), point(1, asleep: 420, deep: 80, core: 340, rem: nil)]
        #expect(labels(points) == ["Profond", "Léger"])
    }

    @Test func legendNamesTheUnstagedRestOnlyWhenDrawn() {
        #expect(labels([point(0, asleep: 480, deep: 60, core: 280, rem: 120, unspecified: 20)])
            == ["Profond", "Léger", "Paradoxal", "Sans phase"])
        #expect(labels([point(0, asleep: 480, deep: 60, core: 300, rem: 120, unspecified: 0)])
            == ["Profond", "Léger", "Paradoxal"])
    }

    /// 20 secondes sans phase en moyenne s'arrondissent à 0 min : ni tranche ni entrée de légende, comme la phrase de la barre.
    @Test func aFewUnstagedSecondsAreNeitherDrawnNorNamed() {
        let barely = point(0, asleep: 480, deep: 60, core: 299.67, rem: 120, unspecified: 0.33)
        #expect(SleepChartLayers.layers(of: barely).map(\.kind) == [.stage(.deep), .stage(.core), .stage(.rem)])
        #expect(labels([barely]) == ["Profond", "Léger", "Paradoxal"])
    }

    @Test func unstagedPeriodWithoutDeepNamesOnlyTheRest() {
        #expect(labels([point(0, asleep: 420, deep: nil), point(1, asleep: 400, deep: nil)]) == ["Autres phases"])
        #expect(labels([point(0, asleep: 420, deep: 60)]) == ["Profond", "Autres phases"])
    }

    /// Une nuit à 0 min ne dessine rien et n'entre pas dans la légende, mais garde une marque vide pour VoiceOver.
    @Test func emptyBarKeepsOneAccessibleMarkOutOfTheLegend() {
        let empty = point(0, asleep: 0, deep: nil)
        #expect(SleepChartLayers.layers(of: empty).isEmpty)
        #expect(SleepChartLayers.marks(of: empty) == [SleepLayer(kind: .otherInk, start: 0, end: 0)])
        #expect(labels([empty]).isEmpty)
        let full = point(1, asleep: 420, deep: 60)
        #expect(SleepChartLayers.marks(of: full) == SleepChartLayers.layers(of: full))
    }

    @Test func emptyPeriodHasNoLegend() {
        #expect(labels([]).isEmpty)
    }
}
