import PulseDomain
import SwiftUI

// MARK: - Retour au toucher

/// Le style des cartes et des lignes qu'on touche : elles s'enfoncent légèrement et un tic haptique confirme le toucher.
/// À poser à la place de `.plain` sur un `Button` ou un `NavigationLink` qui porte une carte.
public struct PressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration)
    }
}

private struct PressableBody: View {
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .pulseAnimation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

// MARK: - Pastille d'action

/// Une petite action en pastille (« Lancer », « + Nouvelle », « Mon programme ») : `prominent` la remplit de l'accent, sinon
/// elle est cernée d'un filet. Cible d'au moins 44 pt de haut.
public struct PillButtonStyle: ButtonStyle {
    private let prominent: Bool

    public init(prominent: Bool = false) {
        self.prominent = prominent
    }

    public func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, prominent: prominent)
    }
}

private struct PillBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    @Environment(\.pulseTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(prominent ? Color(palette.accentInk) : PulsePalette.text)
            .padding(.horizontal, 16)
            .frame(minWidth: 44, minHeight: 36)
            .background {
                if prominent {
                    Capsule().fill(Color(palette.accent))
                } else {
                    Capsule().strokeBorder(PulsePalette.ink.opacity(0.2), lineWidth: 1)
                }
            }
            // La pastille est plus basse que 44 pt à l'œil, sa cible ne l'est pas.
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .pulseAnimation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

// MARK: - Pastille d'icône

/// L'icône d'une tuile ou d'une ligne, dans un rond. `.neutral` : cerné d'un filet ; `.accent` : sur l'accent doux du thème ;
/// `.inverted` : plein d'encre, l'icône en creux.
public struct IconChip: View {
    public enum Tone: Sendable {
        case neutral
        case accent
        case inverted
    }

    private let systemName: String
    private let tone: Tone
    private let size: CGFloat
    @Environment(\.pulseTheme) private var theme

    public init(systemName: String, tone: Tone = .neutral, size: CGFloat = 40) {
        self.systemName = systemName
        self.tone = tone
        self.size = size
    }

    public var body: some View {
        let palette = PulsePalette.accent(for: theme)
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(foreground(palette))
            .frame(width: size, height: size)
            .background {
                switch tone {
                case .neutral: Circle().strokeBorder(PulsePalette.ink.opacity(0.16), lineWidth: 1)
                case .accent: Circle().fill(palette.soft)
                case .inverted: Circle().fill(PulsePalette.ink)
                }
            }
            .accessibilityHidden(true)
    }

    private func foreground(_ palette: AccentPalette) -> Color {
        switch tone {
        case .neutral: PulsePalette.text
        case .accent: Color(palette.accent)
        case .inverted: PulsePalette.page
        }
    }
}

// MARK: - En-tête de section

/// Le titre d'une section (« Mes routines », « Les signaux ») et, à droite, ses actions. Les actions passent sous le titre dès
/// qu'elles ne tiennent plus à côté (texte agrandi, écran étroit) : elles ne sont jamais tronquées.
public struct PulseSectionHeader<Actions: View>: View {
    private let title: String
    private let actions: Actions

    public init(_ title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                titleText
                Spacer(minLength: 8)
                HStack(spacing: 8) { actions }
            }
            VStack(alignment: .leading, spacing: 6) {
                titleText
                HStack(spacing: 8) { actions }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var titleText: some View {
        Text(title)
            .font(PulseFont.title(.title3, weight: .semibold))
            .foregroundStyle(PulsePalette.text)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

public extension PulseSectionHeader where Actions == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - Ligne

/// Une ligne d'entrée : pastille d'icône, titre, détail, et un chevron quand elle mène ailleurs. Sa carte est incluse : à poser
/// dans un `Button` ou un `NavigationLink` stylé `PressableButtonStyle`.
public struct PulseRow<Trailing: View>: View {
    private let systemImage: String
    private let iconTone: IconChip.Tone
    private let title: String
    private let detail: String?
    private let trailing: Trailing

    public init(systemImage: String, iconTone: IconChip.Tone = .neutral, title: String, detail: String? = nil,
                @ViewBuilder trailing: () -> Trailing) {
        self.systemImage = systemImage
        self.iconTone = iconTone
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    public var body: some View {
        ObsidianCard {
            HStack(spacing: 14) {
                IconChip(systemName: systemImage, tone: iconTone)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }
}

public extension PulseRow where Trailing == RowChevron {
    /// Une ligne qui mène à un autre écran : chevron à droite.
    init(systemImage: String, iconTone: IconChip.Tone = .neutral, title: String, detail: String? = nil) {
        self.init(systemImage: systemImage, iconTone: iconTone, title: title, detail: detail) { RowChevron() }
    }
}

/// Le chevron d'une ligne qui mène ailleurs.
public struct RowChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(PulsePalette.muted)
            .accessibilityHidden(true)
    }
}

// MARK: - Barre d'action ancrée

public extension View {
    /// Ancre l'action principale de l'écran en bas, sous le pouce, dans une barre de verre qui laisse défiler le contenu
    /// derrière elle. Rien n'est ancré quand `isPresented` est faux.
    func pulseDockedAction(isPresented: Bool = true, @ViewBuilder _ action: () -> some View) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if isPresented {
                DockedActionBar(content: action())
                    .pulseTransition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

private struct DockedActionBar<Content: View>: View {
    let content: Content

    var body: some View {
        GlassEffectContainer {
            content
                .padding(6)
                .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, PulseMetrics.spacing)
        .padding(.bottom, 8)
    }
}

#Preview("Composants d'interaction") {
    ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            PulseSectionHeader("Mes routines") {
                Button("Mon programme") {}.buttonStyle(PillButtonStyle())
                Button("+ Nouvelle") {}.buttonStyle(PillButtonStyle(prominent: true))
            }
            Button {} label: {
                PulseRow(systemImage: "book.closed", title: "Bibliothèque d'exercices", detail: "Fiches et consignes")
            }
            .buttonStyle(PressableButtonStyle())
            HStack {
                IconChip(systemName: "dumbbell.fill")
                IconChip(systemName: "figure.run", tone: .accent)
                IconChip(systemName: "bolt.fill", tone: .inverted)
            }
        }
        .padding()
    }
    .background(PulsePalette.background)
    .pulseDockedAction {
        Button("Démarrer") {}.buttonStyle(PrimaryButtonStyle())
    }
}
