import SwiftUI

/// Deux onglets temporaires : le diagnostic Apple Santé (M1) et les données (M2).
struct RootTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            Tab(String(localized: "Santé"), systemImage: "heart") {
                HealthDiagnosticsView(model: HealthDiagnosticsModel(dependencies: dependencies))
            }
            Tab(String(localized: "Données"), systemImage: "externaldrive") {
                DataDebugView(model: DataDebugModel(dependencies: dependencies))
            }
        }
    }
}
