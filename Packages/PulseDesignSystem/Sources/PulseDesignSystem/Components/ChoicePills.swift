import PulseDomain
import SwiftUI

/// Ce que VoiceOver lit d'une pilule et du groupe qui la contient. Des fonctions pures.
enum PillAccessibility {
    /// La hauteur minimale d'une pilule : la cible tactile de 44 points.
    static let minHeight: CGFloat = 44

    /// L'étiquette parlée de la pilule si elle en a une (« 3 séances par semaine »), sinon son texte visible.
    static func label(visible: String, spoken: String?) -> String {
        guard let spoken, !spoken.isEmpty else { return visible }
        return spoken
    }

    /// Le nom du groupe de pilules (la question posée) ; `nil` sans nom, le groupe n'est alors pas un conteneur.
    static func groupLabel(_ label: String?) -> String? {
        guard let label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return label
    }
}

private struct PillGroupModifier: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label = PillAccessibility.groupLabel(label) {
            content
                .accessibilityElement(children: .contain)
                .accessibilityLabel(label)
        } else {
            content
        }
    }
}

/// Pilules à choix unique (`.chip` de la maquette) : la sélectionnée se remplit de l'accent du thème.
/// `groupLabel` nomme le groupe pour VoiceOver (la question) ; `spokenLabel` donne à une pilule une étiquette parlée plus
/// complète que son texte (« 3 séances par semaine » pour « 3 »).
public struct ChoicePills<Value: Hashable>: View {
    private let options: [(value: Value, label: String)]
    @Binding private var selection: Value?
    private let groupLabel: String?
    private let spokenLabel: (Value) -> String?

    public init(
        options: [(value: Value, label: String)],
        selection: Binding<Value?>,
        groupLabel: String? = nil,
        spokenLabel: @escaping (Value) -> String? = { _ in nil }
    ) {
        self.options = options
        _selection = selection
        self.groupLabel = groupLabel
        self.spokenLabel = spokenLabel
    }

    public var body: some View {
        PillFlowLayout {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                PillButton(
                    label: option.label, spokenLabel: spokenLabel(option.value), isSelected: selection == option.value
                ) {
                    guard selection != option.value else { return }
                    selection = option.value
                    PulseHaptics.selection()
                }
            }
        }
        .modifier(PillGroupModifier(label: groupLabel))
    }
}

/// Pilules à choix multiple : chaque touche bascule l'appartenance à l'ensemble.
public struct MultiChoicePills<Value: Hashable>: View {
    private let options: [(value: Value, label: String)]
    @Binding private var selection: Set<Value>
    private let groupLabel: String?
    private let spokenLabel: (Value) -> String?

    public init(
        options: [(value: Value, label: String)],
        selection: Binding<Set<Value>>,
        groupLabel: String? = nil,
        spokenLabel: @escaping (Value) -> String? = { _ in nil }
    ) {
        self.options = options
        _selection = selection
        self.groupLabel = groupLabel
        self.spokenLabel = spokenLabel
    }

    public var body: some View {
        PillFlowLayout {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                PillButton(
                    label: option.label, spokenLabel: spokenLabel(option.value), isSelected: selection.contains(option.value)
                ) {
                    if selection.contains(option.value) {
                        selection.remove(option.value)
                    } else {
                        selection.insert(option.value)
                    }
                    PulseHaptics.selection()
                }
            }
        }
        .modifier(PillGroupModifier(label: groupLabel))
    }
}

struct PillButton: View {
    let label: String
    var spokenLabel: String?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(isSelected ? .heavy : .semibold))
                .foregroundStyle(isSelected ? Color(palette.accentInk) : PulsePalette.text2)
                .padding(.horizontal, 16)
                .frame(minHeight: PillAccessibility.minHeight)
                .background {
                    if isSelected {
                        Capsule().fill(Color(palette.accent))
                    } else {
                        Capsule().strokeBorder(PulsePalette.ink.opacity(0.18), lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PillAccessibility.label(visible: label, spoken: spokenLabel))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Retour à la ligne automatique des pilules (`.chips.wrap`).
struct PillFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(width: bounds.width, subviews: subviews).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > 0, origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + rowHeight + spacing)
                rowHeight = 0
            }
            frames.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, origin.x - spacing)
        }
        return (frames, CGSize(width: usedWidth, height: origin.y + rowHeight))
    }
}

private struct ChoicePillsPreview: View {
    @State private var single: String? = "intermediate"
    @State private var multiple: Set<String> = ["knees"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ChoicePills(
                options: [
                    ("beginner", "Je débute"), ("novice", "Moins d'un an"),
                    ("intermediate", "1 à 3 ans"), ("advanced", "Plus de 3 ans")
                ],
                selection: $single,
                groupLabel: "Ton niveau"
            )
            MultiChoicePills(
                options: [("shoulders", "Épaules"), ("lowerBack", "Lombaires"), ("knees", "Genoux"), ("wrists", "Poignets")],
                selection: $multiple,
                groupLabel: "Zones sensibles"
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PulsePalette.background)
    }
}

#Preview {
    ChoicePillsPreview()
}

#Preview("Accessibilité 3") {
    ChoicePillsPreview()
        .dynamicTypeSize(.accessibility3)
}
