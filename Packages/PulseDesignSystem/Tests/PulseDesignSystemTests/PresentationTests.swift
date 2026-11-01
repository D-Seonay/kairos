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
