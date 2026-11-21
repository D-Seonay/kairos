import PulseDesignSystem
import SwiftUI

/// Confirmation de la suppression totale (spec M2 §7.1). Un échec garde la feuille ouverte avec son message ; elle ne se ferme
/// (et `onErased` ne part) qu'une fois tout supprimé.
struct EraseConfirmationView: View {
    static let confirmationWord = "SUPPRIMER"

    let model: DataDebugModel
    /// Appelé après une suppression réussie, une fois la feuille fermée.
    let onErased: () async -> Void
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
                    Text(String(localized: "Les entraînements de musculation que Pulse y a enregistrés, et leur énergie."))
                        .font(.footnote).foregroundStyle(.secondary)
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
                                guard model.didErase else { return }
                                dismiss()
                                await onErased()
                            }
                        }
                        .disabled(typed != Self.confirmationWord)
                    }
                    if let error = model.lastError, !model.isBusy {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.bad)
                    }
                }
            }
            .navigationTitle(String(localized: "Tout supprimer"))
            .toolbar { Button(String(localized: "Annuler")) { dismiss() }.disabled(model.isBusy) }
        }
        .interactiveDismissDisabled(model.isBusy)
    }
}
