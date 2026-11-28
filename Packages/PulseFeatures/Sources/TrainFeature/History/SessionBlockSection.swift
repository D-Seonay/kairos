import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Un exercice de la séance, en lecture seule : son nom, sa note, puis ses séries.
struct SessionBlockSection: View {
    let block: SessionExerciseBlock

    var body: some View {
        Section {
            if let note = block.note {
                Label(note, systemImage: "note.text")
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .accessibilityLabel(String(localized: "Note : \(note)", bundle: .module))
            }
            ForEach(block.sets) { set in
                SetRow(set: set)
            }
        } header: {
            if let label = block.supersetLabel {
                Text(String(localized: "\(label) · \(block.name)", bundle: .module))
                    .accessibilityLabel(String(localized: "\(block.name), super set \(label)", bundle: .module))
            } else {
                Text(block.name)
            }
        }
        .listRowBackground(PulsePalette.surface)
    }
}

/// Une série : « 70 × 5 », son type s'il n'est pas « de travail », son RPE et la mention de record.
private struct SetRow: View {
    let set: SessionSetLine

    var body: some View {
        HStack(spacing: 10) {
            Text(set.text)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(set.type == .warmup ? PulsePalette.text2 : PulsePalette.text)
            if let label = typeLabel {
                Badge(text: label, color: PulsePalette.text2)
            }
            Spacer(minLength: 0)
            if let rpe = set.rpe {
                Text(String(localized: "RPE \(PulseFormat.decimal(rpe, maxFractionDigits: 1))", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
            if set.isRecord {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(PulsePalette.gold)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TrainText.sessionSetSpoken(set))
    }

    private var typeLabel: String? {
        switch set.type {
        case .working: nil
        case .warmup: String(localized: "Échauffement", bundle: .module)
        case .drop: String(localized: "Dégressive", bundle: .module)
        case .failure: String(localized: "À l'échec", bundle: .module)
        }
    }
}
