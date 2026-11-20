import PulseDomain
import SwiftUI

/// Rangée L M M J V S D, lundi en premier : un jour sélectionné est un jour de repos imposé, une pastille éteinte barrée
/// d'une diagonale, comme une case rayée au calendrier.
public struct WeekdayToggleRow: View {
    @Binding private var selection: Set<Weekday>

    public init(selection: Binding<Set<Weekday>>) {
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let isRest = selection.contains(day)
                Button {
                    toggle(day)
                } label: {
                    Text(day.initial)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(isRest ? PulsePalette.muted : PulsePalette.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isRest ? Color.clear : PulsePalette.surface2, in: shape)
                        .overlay { shape.strokeBorder(PulsePalette.ink.opacity(isRest ? 0.3 : 0.08), lineWidth: 1) }
                        .overlay { if isRest { RestStrike().stroke(PulsePalette.muted, lineWidth: 1).clipShape(shape) } }
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.localizedName)
                .accessibilityValue(isRest ? String(localized: "Jour de repos", bundle: .module) : "")
                .accessibilityAddTraits(isRest ? .isSelected : [])
            }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    private func toggle(_ day: Weekday) {
        if selection.contains(day) {
            selection.remove(day)
        } else {
            selection.insert(day)
        }
        PulseHaptics.selection()
    }
}

/// La diagonale d'un jour de repos, du coin bas gauche au coin haut droit.
private struct RestStrike: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

extension Weekday {
    /// L'initiale affichée sur le bouton (« M » pour mardi comme pour mercredi).
    var initial: String {
        switch self {
        case .monday: String(localized: "L", bundle: .module, comment: "Initiale de lundi")
        case .tuesday: String(localized: "M", bundle: .module, comment: "Initiale de mardi")
        case .wednesday: String(localized: "M", bundle: .module, comment: "Initiale de mercredi")
        case .thursday: String(localized: "J", bundle: .module, comment: "Initiale de jeudi")
        case .friday: String(localized: "V", bundle: .module, comment: "Initiale de vendredi")
        case .saturday: String(localized: "S", bundle: .module, comment: "Initiale de samedi")
        case .sunday: String(localized: "D", bundle: .module, comment: "Initiale de dimanche")
        }
    }

    /// Le nom complet, lu par VoiceOver.
    var localizedName: String {
        switch self {
        case .monday: String(localized: "Lundi", bundle: .module)
        case .tuesday: String(localized: "Mardi", bundle: .module)
        case .wednesday: String(localized: "Mercredi", bundle: .module)
        case .thursday: String(localized: "Jeudi", bundle: .module)
        case .friday: String(localized: "Vendredi", bundle: .module)
        case .saturday: String(localized: "Samedi", bundle: .module)
        case .sunday: String(localized: "Dimanche", bundle: .module)
        }
    }
}

private struct WeekdayToggleRowPreview: View {
    @State private var rest: Set<Weekday> = [.sunday]

    var body: some View {
        WeekdayToggleRow(selection: $rest)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PulsePalette.background)
    }
}

#Preview {
    WeekdayToggleRowPreview()
}
