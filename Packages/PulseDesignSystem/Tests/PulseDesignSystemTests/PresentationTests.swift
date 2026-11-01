import PulseDomain
import Testing

@testable import PulseDesignSystem

@Test func categoryNamesAndTones() {
    #expect(RecoveryCategory.optimal.localizedName == "Forme optimale")
    #expect(RecoveryCategory.normal.localizedName == "Forme normale")
    #expect(RecoveryCategory.moderateFatigue.localizedName == "Fatigue modérée")
    #expect(RecoveryCategory.overreached.localizedName == "Surmenage")
    #expect(RecoveryCategory.optimal.tone == .positive)
    #expect(RecoveryCategory.normal.tone == .positive)
    #expect(RecoveryCategory.moderateFatigue.tone == .caution)
    #expect(RecoveryCategory.overreached.tone == .critical)
}

@Test func focusSplitLabels() {
    #expect(FocusSplit.label(focus: 0.4) == "60 / 40")
    #expect(FocusSplit.label(focus: 0) == "100 / 0")
    #expect(FocusSplit.label(focus: 1) == "0 / 100")
    #expect(FocusSplit.label(focus: 0.55) == "45 / 55")
}

@Test func focusSplitClampsOutOfRangeValues() {
    #expect(FocusSplit.label(focus: -0.3) == "100 / 0")
    #expect(FocusSplit.label(focus: 1.7) == "0 / 100")
}

@Test func focusSplitTreatsNaNAsBalanced() {
    #expect(FocusSplit.label(focus: .nan) == "50 / 50")
    #expect(FocusSplit.label(focus: .infinity) == "0 / 100")
    #expect(FocusSplit.label(focus: -.infinity) == "100 / 0")
}

@Test func weekdayLabelsStartOnMonday() {
    #expect(Weekday.allCases.map(\.initial) == ["L", "M", "M", "J", "V", "S", "D"])
    #expect(Weekday.allCases.map(\.localizedName)
        == ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"])
}

@Test func badgeColorFollowsTheSurface() {
    #expect(CategoryBadge(category: .optimal).onOpal == false)
    #expect(CategoryBadge(category: .optimal, onOpal: true).onOpal)
    #expect(CategoryTone.positive.color(onOpal: true) == PulsePalette.opalOK)
    #expect(CategoryTone.critical.color(onOpal: false) == PulsePalette.bad)
}
