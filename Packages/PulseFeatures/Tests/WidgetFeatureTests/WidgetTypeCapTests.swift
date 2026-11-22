import SwiftUI
import Testing
@testable import WidgetFeature

struct WidgetTypeCapTests {
    @Test func everyWidgetGrowsUpToXXXLargeAndNeverPastAccessibility3() {
        #expect(WidgetTypeCap.all.count == 9)
        for cap in WidgetTypeCap.all {
            #expect(cap >= .xxxLarge)
            #expect(cap <= .accessibility3)
        }
        #expect(WidgetTypeCap.weekLarge == .xxxLarge)
        #expect(WidgetTypeCap.sessionRectangular == .xxxLarge)
    }
}
