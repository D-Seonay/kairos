import SwiftUI

/// Pilules à choix unique (`.chip` de la maquette) : la sélectionnée est pleine, en blanc.
public struct ChoicePills<Value: Hashable>: View {
    private let options: [(value: Value, label: String)]
    @Binding private var selection: Value?

    public init(options: [(value: Value, label: String)], selection: Binding<Value?>) {
        self.options = options
        _selection = selection
    }

    public var body: some View {
        PillFlowLayout {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                PillButton(label: option.label, isSelected: selection == option.value) {
                    guard selection != option.value else { return }
                    selection = option.value
                    PulseHaptics.selection()
                }
            }
        }
    }
}

/// Pilules à choix multiple : chaque touche bascule l'appartenance à l'ensemble.
public struct MultiChoicePills<Value: Hashable>: View {
    private let options: [(value: Value, label: String)]
    @Binding private var selection: Set<Value>

    public init(options: [(value: Value, label: String)], selection: Binding<Set<Value>>) {
        self.options = options
        _selection = selection
    }

    public var body: some View {
        PillFlowLayout {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                PillButton(label: option.label, isSelected: selection.contains(option.value)) {
                    if selection.contains(option.value) {
                        selection.remove(option.value)
                    } else {
                        selection.insert(option.value)
                    }
                    PulseHaptics.selection()
                }
            }
        }
    }
}

struct PillButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? PulsePalette.background : PulsePalette.text2)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(isSelected ? PulsePalette.text : PulsePalette.surface2, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                selection: $single
            )
            MultiChoicePills(
                options: [("shoulders", "Épaules"), ("lowerBack", "Lombaires"), ("knees", "Genoux"), ("wrists", "Poignets")],
                selection: $multiple
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
