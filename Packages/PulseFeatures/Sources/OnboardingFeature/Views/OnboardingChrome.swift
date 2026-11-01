import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Titre et sous-titre d'un écran d'onboarding (`.ob-title`).
struct OnboardingTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title, weight: .heavy))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(PulsePalette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Titre d'une section d'un écran (`.section-title`).
struct OnboardingSectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(PulsePalette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Une ligne d'information : pastille d'icône, titre, détail (`.perm`).
struct OnboardingInfoRow: View {
    let systemImage: String
    let title: String
    let detail: String
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Color(palette.accent))
                .frame(width: 36, height: 36)
                .background(palette.soft, in: RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulsePalette.text)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Un champ du formulaire : son libellé au-dessus, sa saisie dans un cadre (`.field`).
struct OnboardingField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PulsePalette.muted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Le cadre d'une saisie : fond `surface`, bord `line`.
    func onboardingInput() -> some View {
        let shape = RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous)
        return padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(PulsePalette.surface, in: shape)
            .overlay(shape.strokeBorder(PulsePalette.line))
    }
}

extension OnboardingModel {
    /// Un champ du profil lu comme optionnel pour `ChoicePills` ; une valeur `nil` écrite est ignorée.
    func optionalBinding<Value>(_ keyPath: WritableKeyPath<UserProfile, Value>) -> Binding<Value?> {
        Binding(
            get: { self.profile[keyPath: keyPath] },
            set: { newValue in
                if let newValue { self.profile[keyPath: keyPath] = newValue }
            }
        )
    }
}

/// Le squelette d'un écran : contenu défilant, pied collé en bas avec le bouton principal et le message d'erreur.
struct OnboardingScreen<Content: View, Footer: View>: View {
    let errorMessage: String?
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(.horizontal, PulseMetrics.spacing)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                footer
            }
            .padding(.horizontal, PulseMetrics.spacing)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(fade)
        }
    }

    private var fade: some View {
        LinearGradient(
            stops: [.init(color: .clear, location: 0), .init(color: PulsePalette.background, location: 0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Un bouton dont l'action est asynchrone : une seconde touche pendant l'action est ignorée.
struct OnboardingButton<Style: ButtonStyle>: View {
    let title: String
    let identifier: String
    let style: Style
    let action: @MainActor () async -> Void
    @State private var isRunning = false

    var body: some View {
        Button(title) {
            guard !isRunning else { return }
            isRunning = true
            Task {
                await action()
                isRunning = false
            }
        }
        .buttonStyle(style)
        .accessibilityIdentifier(identifier)
    }
}

/// Une carte de choix unique : titre, détail, coche (`.opt`). La sélectionnée a le bord et le fond accent.
struct OnboardingOptionCard: View {
    let systemImage: String
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        let shape = RoundedRectangle(cornerRadius: PulseMetrics.radiusSmall, style: .continuous)
        Button {
            guard !isSelected else { return }
            action()
            PulseHaptics.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color(palette.accent) : PulsePalette.text2)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PulsePalette.text)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color(palette.accent) : PulsePalette.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PulseMetrics.spacing)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? palette.soft : PulsePalette.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color(palette.accent) : .clear, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
