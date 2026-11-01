import PulseDesignSystem
import SwiftUI

/// L'onglet « Profil » de M3a : le prénom, puis les deux écrans de debug (diagnostic Apple Santé et données).
struct ProfileHubView: View {
    let dependencies: AppDependencies
    let firstName: String?
    let onErased: () async -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(displayName)
                        .font(.system(.title2, weight: .heavy))
                        .foregroundStyle(PulsePalette.text)
                }
                Section(String(localized: "Debug")) {
                    NavigationLink(String(localized: "Santé (diagnostic)")) {
                        HealthDiagnosticsView(model: HealthDiagnosticsModel(dependencies: dependencies, today: dependencies.now()))
                    }
                    NavigationLink(String(localized: "Données")) {
                        DataDebugView(model: DataDebugModel(dependencies: dependencies), onErased: onErased)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulsePalette.background)
            .navigationTitle(String(localized: "Profil"))
        }
    }

    private var displayName: String {
        guard let firstName, !firstName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return String(localized: "Ton profil")
        }
        return firstName
    }
}

#Preview {
    ProfileHubView(dependencies: .preview(), firstName: "Mathéo") {}
}
