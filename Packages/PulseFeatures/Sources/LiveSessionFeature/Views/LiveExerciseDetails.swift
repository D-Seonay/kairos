import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Sous le nom d'un exercice : sa note (reprise de la dernière fois, en tête, modifiable d'un appui), son super set, « Dernière
/// fois », la baisse du jour avec « Remettre », ce que le jour a changé et le RPE plafond.
struct LiveExerciseDetails: View {
    let exercise: LiveExercise
    let onEditNote: () -> Void
    let onRestore: () -> Void
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        if let note = exercise.note {
            Button(action: onEditNote) {
                Label {
                    Text(note).multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "pin.fill").accessibilityHidden(true)
                }
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Note : \(note)", bundle: .module))
            .accessibilityHint(String(localized: "Modifie la note", bundle: .module))
        }
        if let group = exercise.supersetGroup {
            Text(LiveExerciseCard.supersetText(group: group))
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
        }
        if let lastTime = exercise.lastTimeText {
            Text(lastTime)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .accessibilityLabel(exercise.lastTimeSpoken ?? lastTime)
        }
        if let drop = exercise.loadDrop {
            loadDrop(drop, accent: accent)
        }
        if let dayNote = exercise.dayNote {
            Label {
                Text(dayNote)
            } icon: {
                Image(systemName: "sparkles").accessibilityHidden(true)
            }
            .font(.footnote)
            .foregroundStyle(accent)
        }
        if let cap = exercise.rpeCap {
            Text(LiveExerciseCard.rpeCapText(cap)).font(.footnote.weight(.semibold)).foregroundStyle(PulsePalette.warn)
        }
    }

    /// « Reprise après 5 semaines : −15 % » et « Remettre 80 kg » : la baisse reste une proposition.
    private func loadDrop(_ drop: LiveLoadDrop, accent: Color) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { dropLine(drop, accent: accent); restoreButton(drop) }
            VStack(alignment: .leading, spacing: 4) { dropLine(drop, accent: accent); restoreButton(drop) }
        }
    }

    private func dropLine(_ drop: LiveLoadDrop, accent: Color) -> some View {
        Label {
            Text(drop.text)
        } icon: {
            Image(systemName: "arrow.down.right").accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(accent)
    }

    private func restoreButton(_ drop: LiveLoadDrop) -> some View {
        Button(action: onRestore) {
            Text(Self.restoreText(drop))
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityHint(String(localized: "Reprend les charges de la dernière fois sur les séries qui restent",
                                  bundle: .module))
    }

    /// « Remettre 80 kg », ou « Remettre les charges » quand les séries n'avaient pas toutes la même.
    nonisolated static func restoreText(_ drop: LiveLoadDrop) -> String {
        guard let weight = drop.originalWeightKg else { return String(localized: "Remettre les charges", bundle: .module) }
        return String(localized: "Remettre \(PulseFormat.decimal(weight, maxFractionDigits: 2)) kg", bundle: .module)
    }
}
