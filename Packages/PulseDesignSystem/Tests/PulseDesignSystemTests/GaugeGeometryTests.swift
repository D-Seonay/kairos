import CoreGraphics
import PulseDomain
import Testing

@testable import PulseDesignSystem

@Test func anglesCoverTheArc() {
    #expect(GaugeGeometry.angle(for: 0).degrees == 150)
    #expect(GaugeGeometry.angle(for: 50).degrees == 270)
    #expect(GaugeGeometry.angle(for: 100).degrees == 390)
    #expect(GaugeGeometry.angle(for: -5).degrees == 150)
    #expect(GaugeGeometry.angle(for: 120).degrees == 390)
}

@Test func nonFiniteScoreFallsBackToTheStart() {
    #expect(GaugeGeometry.angle(for: .nan).degrees == 150)
}

@Test func thresholdsMatchTheCategoryBounds() {
    #expect(GaugeGeometry.thresholdFractions == [0.40, 0.65, 0.90])
}

@Test func midScoreSitsAtTheTop() {
    let point = GaugeGeometry.point(for: 50, in: CGRect(x: 0, y: 0, width: 200, height: 200), lineWidth: 10)
    #expect(abs(point.x - 100) < 0.001 && abs(point.y - 5) < 0.001)   // rayon = 100 - lineWidth / 2
}

@Test func endsSitAtTheBottomCorners() {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
    let start = GaugeGeometry.point(for: 0, in: rect, lineWidth: 0)
    let end = GaugeGeometry.point(for: 100, in: rect, lineWidth: 0)
    #expect(abs(start.x - (100 - 100 * 0.8660254)) < 0.001 && abs(start.y - 150) < 0.001)
    #expect(abs(end.x - (100 + 100 * 0.8660254)) < 0.001 && abs(end.y - 150) < 0.001)
}

@Test func accessibilityLabelNamesTheCategory() {
    #expect(RecoveryGauge.accessibilityLabel(score: 58.4, category: .moderateFatigue) == "Récupération 58 sur 100, fatigue modérée")
    #expect(RecoveryGauge.accessibilityLabel(score: nil, category: nil) == "Récupération pas encore calculée")
}

@Test func accessibilityLabelRoundsAndSurvivesMissingCategory() {
    #expect(RecoveryGauge.accessibilityLabel(score: 58.6, category: .normal) == "Récupération 59 sur 100, forme normale")
    #expect(RecoveryGauge.accessibilityLabel(score: 71, category: nil) == "Récupération 71 sur 100")
    #expect(RecoveryGauge.accessibilityLabel(score: nil, category: .optimal) == "Récupération pas encore calculée")
}

@Test func stillGaugeStartsWithTheMarkerOnTheScore() {
    #expect(RecoveryGauge.initialScore(score: 50, animatesReveal: false) == 50)
    #expect(RecoveryGauge.initialScore(score: 120, animatesReveal: false) == 100)
    #expect(RecoveryGauge.initialScore(score: nil, animatesReveal: false) == 0)
    #expect(RecoveryGauge.initialScore(score: .nan, animatesReveal: false) == 0)
    let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
    let point = GaugeGeometry.point(for: RecoveryGauge.initialScore(score: 50, animatesReveal: false), in: rect, lineWidth: 10)
    #expect(abs(point.x - 100) < 0.001 && abs(point.y - 5) < 0.001)   // le repère est en haut de l'arc, pas au départ
}

@Test func animatedGaugeStartsWithTheMarkerAtTheStart() {
    #expect(RecoveryGauge.initialScore(score: 50, animatesReveal: true) == 0)
}
