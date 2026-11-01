import PulseContent
import PulseDomain
import Testing

private func check(_ raw: String, _ name: String) {
    #expect(!name.isEmpty && name != raw, Comment(rawValue: raw))
}

@Test func everyEnumHasALocalizedName() {
    for item in Muscle.allCases { check(item.rawValue, item.localizedName) }
    for item in Equipment.allCases { check(item.rawValue, item.localizedName) }
    for item in MovementPattern.allCases { check(item.rawValue, item.localizedName) }
    for item in BodyRegion.allCases { check(item.rawValue, item.localizedName) }
    for item in LoadKind.allCases { check(item.rawValue, item.localizedName) }
    #expect(Muscle.chest.localizedName == "Pectoraux")
    #expect(Equipment.cable.localizedName == "Poulie")
    #expect(MovementPattern.horizontalPull.localizedName == "Tirage horizontal")
}

@Test func runTypeAndFocusHaveFrenchNames() {
    #expect(RunType.allCases.map(\.localizedName) == ["Sortie facile", "Fractionné", "Sortie longue"])
    #expect(TrainingFocus.allCases.map(\.localizedName) == ["Force", "Équilibré", "Endurance"])
}
