import Accessibility
import Foundation
import Testing

@testable import PulseDesignSystem

private let parisCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private func day(_ day: Int, month: Int = 10) -> Date {
    parisCalendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .distantPast
}

private func descriptor(series: [PulseChartDescriptor.Series], xAxis: PulseChartDescriptor.XAxis = .dates(title: "Date"))
    -> AXChartDescriptor {
    PulseChartDescriptor(
        title: "Charge", summary: "La charge monte.", xAxis: xAxis,
        yAxis: .init(title: "Charge", unit: "kilos", range: 0...100), series: series, calendar: parisCalendar
    ).makeChartDescriptor()
}

@Test func twoDatedSeriesProduceTwoSeries() {
    let built = descriptor(series: [
        .init(name: "Réel", points: [.init(date: day(1), y: 10), .init(date: day(2), y: 20), .init(date: day(3), y: 30)]),
        .init(name: "Prévu", points: [.init(date: day(1), y: 15), .init(date: day(3), y: 25)])
    ])
    #expect(built.series.count == 2)
    #expect(built.series.map(\.name) == ["Réel", "Prévu"])
    #expect(built.series.map(\.dataPoints.count) == [3, 2])
    #expect(built.title == "Charge" && built.summary == "La charge monte.")
}

@Test func yAxisKeepsTheGivenRangeAndTitle() throws {
    let built = descriptor(series: [.init(name: "Réel", points: [.init(date: day(1), y: 10)])])
    #expect(built.yAxis?.title == "Charge")
    #expect(built.yAxis?.range == 0...100)
}

@Test func yValuesAreSpokenWithTheirUnit() throws {
    let built = descriptor(series: [])
    let provider = try #require(built.yAxis?.valueDescriptionProvider)
    #expect(provider(80) == "80 kilos")
    #expect(provider(62.5) == "62,5 kilos")
    #expect(PulseChartDescriptor.speak(value: 12, unit: "") == "12")
}

@Test func yValuesUseTheCallersWordingWhenGiven() throws {
    let built = PulseChartDescriptor(
        title: "Charge", summary: "", xAxis: .dates(title: "Date"),
        yAxis: .init(title: "Charge", unit: "kilos", range: 0...10) { PulseSpoken.kilos($0) }, series: [], calendar: parisCalendar
    ).makeChartDescriptor()
    let provider = try #require(built.yAxis?.valueDescriptionProvider)
    #expect(provider(1) == "1 kilo")
    #expect(provider(2) == "2 kilos")
    #expect(provider(62.5) == "62,5 kilos")
}

@Test func datesAreSpokenInFull() throws {
    let built = descriptor(series: [.init(name: "Réel", points: [.init(date: day(28), y: 10), .init(date: day(29), y: 12)])])
    let axis = try #require(built.xAxis as? AXNumericDataAxisDescriptor)
    #expect(axis.title == "Date")
    #expect(axis.valueDescriptionProvider(day(28).timeIntervalSince1970) == "28 octobre")
    #expect(axis.range == day(28).timeIntervalSince1970...day(29).timeIntervalSince1970)
}

@Test func categoriesKeepTheirOrder() throws {
    let built = descriptor(
        series: [.init(name: "Séances", points: [.init(category: "Lundi", y: 2), .init(category: "Mardi", y: 0)])],
        xAxis: .categories(title: "Jour", names: ["Lundi", "Mardi", "Mercredi"])
    )
    let axis = try #require(built.xAxis as? AXCategoricalDataAxisDescriptor)
    #expect(axis.title == "Jour")
    #expect(axis.categoryOrder == ["Lundi", "Mardi", "Mercredi"])
    #expect(built.series.first?.dataPoints.map(\.xValue.__category) == ["Lundi", "Mardi"])
}

@Test func anEmptySeriesHasNoPointAndSaysThereIsNotEnoughData() {
    let built = descriptor(series: [.init(name: "Réel", points: [])])
    #expect(built.series.count == 1)
    #expect(built.series.first?.dataPoints.isEmpty == true)
    #expect(built.summary == "La charge monte. Pas assez de données.")
}

@Test func noSeriesDoesNotCrash() throws {
    let built = descriptor(series: [])
    #expect(built.series.isEmpty)
    let axis = try #require(built.xAxis as? AXNumericDataAxisDescriptor)
    #expect(axis.range.lowerBound < axis.range.upperBound)
}

@Test func aSinglePointHasAUsableRangeAndSaysThereIsNotEnoughData() throws {
    let built = descriptor(series: [.init(name: "Réel", points: [.init(date: day(5), y: 42)])])
    #expect(built.series.first?.dataPoints.count == 1)
    let axis = try #require(built.xAxis as? AXNumericDataAxisDescriptor)
    #expect(axis.range.lowerBound < axis.range.upperBound)
    #expect(built.summary == "La charge monte. Pas assez de données.")
}

@Test func enoughPointsLeaveTheSummaryUntouched() {
    let built = descriptor(series: [.init(name: "Réel", points: [.init(date: day(1), y: 1), .init(date: day(2), y: 2)])])
    #expect(built.summary == "La charge monte.")
}

@Test func nonFiniteValuesAreDropped() {
    let built = descriptor(series: [
        .init(name: "Réel", points: [.init(date: day(1), y: .nan), .init(date: day(2), y: 2), .init(date: day(3), y: .infinity)])
    ])
    #expect(built.series.first?.dataPoints.count == 1)
}
