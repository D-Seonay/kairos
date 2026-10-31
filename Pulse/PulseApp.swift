import SwiftUI

@main
struct PulseApp: App {
    var body: some Scene {
        WindowGroup {
            HealthDiagnosticsView(model: HealthDiagnosticsModel(dependencies: .live()))
        }
    }
}
