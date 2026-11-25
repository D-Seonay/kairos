import PulseLiveActivity
import SwiftUI
import WidgetFeature

extension SessionActivityModel {
    /// La série que « Valider » coche : hors repos seulement, et quand l'app en a fourni une (une séance passée n'a pas d'activité,
    /// une série sans charge ou sans répétitions se saisit dans l'app).
    var validateSetID: UUID? {
        restInterval == nil ? content.nextSetID : nil
    }
}

/// « Valider » : coche la série suivante affichée sans ouvrir l'app, puis l'app lance le repos et met l'activité à jour. Il garde sa
/// largeur à côté de la série suivante, qui se coupe avant lui.
struct SessionValidateButton: View {
    let setID: UUID
    let nextSet: String?
    var height: CGFloat = 44

    var body: some View {
        Button(intent: ValidateSetIntent(setID: setID)) {
            Label(SessionActivityText.validateTitle, systemImage: "checkmark")
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minHeight: height)
                .foregroundStyle(SessionActivityStyle.accentInk)
                .background(SessionActivityStyle.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(SessionActivityText.validateLabel(nextSet: nextSet))
    }
}

/// Hors repos, la série suivante et « Valider » sur une même ligne, à la hauteur du bouton : l'activité garde la place qu'elle
/// avait avec la série suivante seule.
struct SessionValidateRow: View {
    let setID: UUID
    let nextSet: String?
    let lineLimit: Int
    let height: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            if let nextSet {
                SessionNextSetText(nextSet: nextSet, lineLimit: lineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            SessionValidateButton(setID: setID, nextSet: nextSet, height: height)
        }
    }
}
