import CoreGraphics
import Testing

@testable import PulseDesignSystem

@Test func sparklineSpansTheRect() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
    let points = SparklineGeometry.points(values: [10, nil, 20], in: rect, inset: 2)
    #expect(points[0] == CGPoint(x: 2, y: 38) && points[1] == nil && points[2] == CGPoint(x: 98, y: 2))
}

@Test func sparklineSpreadsXEvenlyBetweenTheInsets() {
    let rect = CGRect(x: 10, y: 0, width: 100, height: 40)
    let points = SparklineGeometry.points(values: [1, 2, 3], in: rect, inset: 0)
    #expect(points.map { $0?.x } == [10, 60, 110])
}

@Test func flatSparklineSitsInTheMiddle() {
    let points = SparklineGeometry.points(values: [5, 5], in: CGRect(x: 0, y: 0, width: 100, height: 40), inset: 2)
    #expect(points.map { $0?.y } == [20, 20])
}

@Test func singleValueIsCentered() {
    let points = SparklineGeometry.points(values: [7], in: CGRect(x: 0, y: 0, width: 100, height: 40), inset: 2)
    #expect(points[0]?.x == 50)
}

@Test func emptyAndAllMissingValuesGiveNoPoint() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
    #expect(SparklineGeometry.points(values: [], in: rect, inset: 2).isEmpty)
    #expect(SparklineGeometry.points(values: [nil, nil], in: rect, inset: 2) == [nil, nil])
}

@Test func nonFiniteValuesAreTreatedAsMissing() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
    let points = SparklineGeometry.points(values: [1, .nan, 3, .infinity], in: rect, inset: 0)
    #expect(points[1] == nil && points[3] == nil)
    #expect(points[0]?.y == 40 && points[2]?.y == 0)
}
