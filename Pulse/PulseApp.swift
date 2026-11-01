import SwiftUI

@main
struct PulseApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
    }
}
