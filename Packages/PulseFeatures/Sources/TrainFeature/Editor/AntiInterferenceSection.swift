import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Les trois règles anti-interférence de l'éditeur de programme (maquette `programme`), chacune désactivable (spec M6 §9).
struct AntiInterferenceSection: View {
    let disabled: [AntiInterferenceRule]
    let onChange: (AntiInterferenceRule, Bool) -> Void

    var body: some View {
        Section {
            ForEach(AntiInterferenceRule.allCases, id: \.self) { rule in
                Toggle(isOn: binding(for: rule)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.title(of: rule))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulsePalette.text)
                        Text(Self.detail(of: rule))
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(PulsePalette.ink)
                .frame(minHeight: 44)
            }
        } header: {
            Text(String(localized: "Règles anti-interférence", bundle: .module))
        } footer: {
            Text(String(localized: "Pulse déplace une séance et te dit pourquoi dans le planning. Tu peux toujours garder le jour prévu.",
                        bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    private func binding(for rule: AntiInterferenceRule) -> Binding<Bool> {
        Binding(get: { !disabled.contains(rule) }, set: { onChange(rule, $0) })
    }

    static func title(of rule: AntiInterferenceRule) -> String {
        switch rule {
        case .noIntenseRunAfterHeavyLegs: String(localized: "Jambes lourdes, puis course intense", bundle: .module)
        case .sameDayOrdering: String(localized: "Deux séances le même jour", bundle: .module)
        case .fullRestDay: String(localized: "Un repos complet", bundle: .module)
        }
    }

    static func detail(of rule: AntiInterferenceRule) -> String {
        switch rule {
        case .noIntenseRunAfterHeavyLegs:
            String(localized: "Pas de fractionné ni de sortie longue dans les 36 h qui suivent une séance de jambes lourde.",
                   bundle: .module)
        case .sameDayOrdering:
            String(localized: "Un rappel : au moins 6 h entre les deux, la plus technique le matin.", bundle: .module)
        case .fullRestDay:
            String(localized: "Après 7 jours sans repos et un sommeil court, le prochain jour prévu devient un repos.", bundle: .module)
        }
    }
}
