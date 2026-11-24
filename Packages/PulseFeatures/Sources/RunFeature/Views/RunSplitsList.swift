import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Les temps par kilomètre d'une course, le dernier kilomètre partiel compris (spec V2a §4.5). Chaque ligne est dite en entier :
/// « Kilomètre 3, 5 minutes 32 secondes ».
public struct RunSplitsList: View {
    private let splits: [RunSplit]
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(splits: [RunSplit]) {
        self.splits = splits
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(splits.enumerated()), id: \.offset) { index, split in
                row(split)
                if index < splits.count - 1 {
                    Divider().overlay(PulsePalette.line)
                }
            }
        }
    }

    /// Côte à côte, l'un sous l'autre aux tailles de texte d'accessibilité.
    private func row(_ split: RunSplit) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Text(RunText.splitLabel(split))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(RunText.splitTime(split.seconds))
                .font(PulseFont.value(.body))
                .foregroundStyle(PulsePalette.text)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RunText.splitSpoken(split))
    }
}

#if DEBUG
#Preview("Temps par km") {
    RunSplitsList(splits: RunPreviewSupport.splits)
        .padding()
}

#Preview("Temps par km, accessibilité 3") {
    RunSplitsList(splits: RunPreviewSupport.splits)
        .padding()
        .dynamicTypeSize(.accessibility3)
}
#endif
