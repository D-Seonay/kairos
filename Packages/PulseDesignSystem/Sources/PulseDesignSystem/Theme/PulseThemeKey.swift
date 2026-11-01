import PulseDomain
import SwiftUI

public extension EnvironmentValues {
    /// L'ambiance active, injectée depuis `UserProfile.theme`.
    @Entry var pulseTheme: Theme = .amber
}
