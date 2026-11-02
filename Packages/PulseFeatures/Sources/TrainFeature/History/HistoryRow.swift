import PulseDesignSystem
import SwiftUI

/// Une séance de l'historique : titre et marques (« Hevy », « Abandonnée »), date et durée, séries, tonnage et records.
struct HistoryRow: View {
    let line: HistoryLine
    let dateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(line.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                if line.isImported {
                    Badge(text: String(localized: "Hevy", bundle: .module), color: PulsePalette.text2)
                }
                if line.isAbandoned {
                    Badge(text: String(localized: "Abandonnée", bundle: .module), color: PulsePalette.warn)
                }
                Spacer(minLength: 0)
                if line.recordCount > 0 {
                    Label(String(line.recordCount), systemImage: "trophy.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PulsePalette.gold)
                        .labelStyle(.titleAndIcon)
                }
            }
            Text(dateAndDuration)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
            Text(volume)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var dateAndDuration: String {
        guard let minutes = line.durationMinutes, minutes > 0 else { return dateText }
        return "\(dateText) · \(PulseFormat.duration(minutes: minutes))"
    }

    /// « 12 séries · 4 250 kg ».
    private var volume: String {
        let sets = String(localized: "\(line.workingSets) séries", bundle: .module)
        return "\(sets) · \(HistoryRow.tonnage(line.tonnageKg))"
    }

    static func tonnage(_ kilograms: Double) -> String {
        "\(kilograms.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "fr_FR")))) kg"
    }

    private var accessibilityText: String {
        var parts = [line.title]
        if line.isImported { parts.append(String(localized: "importée de Hevy", bundle: .module)) }
        if line.isAbandoned { parts.append(String(localized: "abandonnée", bundle: .module)) }
        parts.append(dateAndDuration)
        parts.append(volume)
        if line.recordCount > 0 { parts.append(String(localized: "\(line.recordCount) records", bundle: .module)) }
        return parts.joined(separator: ", ")
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
