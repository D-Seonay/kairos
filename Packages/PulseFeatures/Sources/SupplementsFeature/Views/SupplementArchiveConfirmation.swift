import PulseDomain
import SwiftUI

extension View {
    /// La confirmation d'« Archiver », la même partout : le formulaire, le menu contextuel et l'action VoiceOver d'une ligne.
    /// `supplement` non nul la présente ; « Archiver » appelle `onArchive`, et la fermeture remet `supplement` à `nil`.
    func supplementArchiveConfirmation(_ supplement: Binding<Supplement?>,
                                       onArchive: @escaping (Supplement) -> Void) -> some View {
        let isPresented = Binding(get: { supplement.wrappedValue != nil },
                                  set: { if !$0 { supplement.wrappedValue = nil } })
        let title = supplement.wrappedValue.map { String(localized: "Archiver \($0.name) ?", bundle: .module) } ?? ""
        return confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible,
                                  presenting: supplement.wrappedValue) { target in
            Button(String(localized: "Archiver", bundle: .module), role: .destructive) { onArchive(target) }
        } message: { _ in
            Text(String(localized: "Il quitte la liste et ses rappels s'arrêtent. Ses prises restent dans tes données.",
                        bundle: .module))
        }
    }
}
