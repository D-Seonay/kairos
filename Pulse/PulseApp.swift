import SwiftUI

@main
struct PulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: appDelegate.dependencies, router: appDelegate.router,
                        sessionIntents: appDelegate.sessionIntents)
        }
    }
}
