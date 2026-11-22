import PulseDomain
import SwiftUI
import Testing

@testable import PulseDesignSystem

@Test func weekdaySpokenValueSaysWhetherTheDayIsRest() {
    #expect(WeekdayToggleRow.spokenValue(isRest: true) == "Jour de repos")
    #expect(WeekdayToggleRow.spokenValue(isRest: false) == "Jour d'entraînement possible")
    #expect(WeekdayToggleRow.groupLabel == "Jours de repos imposés")
}

@Test func aPillIsSpokenWithItsOwnLabelUnlessAnotherIsGiven() {
    #expect(PillAccessibility.label(visible: "3", spoken: "3 séances par semaine") == "3 séances par semaine")
    #expect(PillAccessibility.label(visible: "3", spoken: nil) == "3")
    #expect(PillAccessibility.label(visible: "3", spoken: "") == "3")
}

@Test func aPillGroupIsNamedByItsQuestion() {
    #expect(PillAccessibility.groupLabel("Comment as-tu dormi ?") == "Comment as-tu dormi ?")
    #expect(PillAccessibility.groupLabel(nil) == nil)
    #expect(PillAccessibility.groupLabel("  ") == nil)
}

@Test func pillsKeepAFortyFourPointTarget() {
    #expect(PillAccessibility.minHeight == 44)
}

@Test func pillActionsStackOnlyAtAccessibilitySizes() {
    #expect(PulseSectionHeader<EmptyView>.stacksActions(accessibilitySize: true))
    #expect(!PulseSectionHeader<EmptyView>.stacksActions(accessibilitySize: false))
}
