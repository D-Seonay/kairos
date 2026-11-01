import SwiftUI

/// Confirmation de la suppression totale (spec M2 §7.1).
struct EraseConfirmationView: View {
    static let confirmationWord = "SUPPRIMER"

    let model: DataDebugModel
    @Environment(\.dismiss) private var dismiss
    @State private var includeAppleHealth = false
    @State private var typed = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "Toutes les données de Pulse seront effacées sur cet iPhone et dans iCloud."))
                    Text(String(localized: "La suppression dans iCloud se termine dès que l'iPhone est en ligne."))
                }
                Section {
                    Toggle(String(localized: "Supprimer aussi ce que Pulse a écrit dans Apple Santé"), isOn: $includeAppleHealth)
                    Text(String(localized: "Disponible quand Pulse écrit dans Apple Santé.")).font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    TextField(String(localized: "Tapez \(Self.confirmationWord) pour confirmer"), text: $typed)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if model.isBusy {
                        HStack { ProgressView(); Text(String(localized: "Suppression en cours…")) }
                    } else {
                        Button(String(localized: "Supprimer définitivement"), role: .destructive) {
                            Task {
                                await model.erase(includeAppleHealth: includeAppleHealth)
                                dismiss()
                            }
                        }
                        .disabled(typed != Self.confirmationWord)
                    }
                }
            }
            .navigationTitle(String(localized: "Tout supprimer"))
            .toolbar { Button(String(localized: "Annuler")) { dismiss() } }
        }
    }
}
