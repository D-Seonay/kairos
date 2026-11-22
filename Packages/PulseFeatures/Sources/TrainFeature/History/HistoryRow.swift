import PulseDesignSystem
import SwiftUI

/// Une séance de l'historique : titre et marques (« Hevy », « Abandonnée »), date et durée, séries, tonnage et records.
struct HistoryRow: View {
    let line: HistoryLine
    let dateText: String
    /// La date en toutes lettres, pour VoiceOver.
    let spokenDateText: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleLine
            Text(dateAndDuration)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
            Text(TrainText.historyVolume(line))
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TrainText.historyRowSpoken(line, spokenDate: spokenDateText))
    }

    /// Le titre, les marques et les records : sur une ligne, ou en colonne aux tailles d'accessibilité où le titre serait écrasé.
    private var titleLine: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(line.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
            if line.isImported {
                Badge(text: String(localized: "Hevy", bundle: .module), color: PulsePalette.text2)
            }
            if line.isAbandoned {
                Badge(text: String(localized: "Abandonnée", bundle: .module), color: PulsePalette.warn)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            if line.recordCount > 0 {
                Label(String(line.recordCount), systemImage: "trophy.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.gold)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private var dateAndDuration: String {
        guard let minutes = line.durationMinutes, minutes > 0 else { return dateText }
        return "\(dateText) · \(PulseFormat.duration(minutes: minutes))"
    }

    static func tonnage(_ kilograms: Double) -> String {
        "\(kilograms.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "fr_FR")))) kg"
    }
}

/// Une pastille de texte (« Hevy », « Abandonnée »).
struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}
