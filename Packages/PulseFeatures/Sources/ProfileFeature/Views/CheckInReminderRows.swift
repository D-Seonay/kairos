import PulseDesignSystem
import PulseServices
import SwiftUI

/// Le rappel de check-in dans les notifications : l'interrupteur, puis l'heure (au réveil habituel ou une heure choisie) et ce
/// qui le déclenche. Le réglage est gardé sur cet iPhone.
struct CheckInReminderRows: View {
    let model: SettingsModel
    let settings: CheckInReminderSettings

    var body: some View {
        SettingsToggle(title: String(localized: "Rappel de check-in", bundle: .module), isOn: Binding(
            get: { settings.enabled },
            set: { enabled in Task { await model.setCheckInReminderEnabled(enabled) } }))
        if settings.enabled {
            Picker(selection: Binding(
                get: { settings.chosenMinutes },
                set: { minutes in Task { await model.setCheckInReminderMinutes(minutes) } })) {
                Text(String(localized: "Au réveil", bundle: .module)).tag(Int?.none)
                ForEach(CheckInReminderRule.choices, id: \.self) { Text(SleepPlan.clockText(minutes: $0)).tag(Int?.some($0)) }
            } label: {
                Text(String(localized: "Heure du rappel", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .pickerStyle(.menu)
            .tint(PulsePalette.text2)
            .accessibilityValue(settings.chosenMinutes.map { ProfileText.clockSpoken(minutes: $0) }
                ?? String(localized: "Au réveil", bundle: .module))
            .frame(minHeight: 44)
        }
        Text(String(localized: "Seulement si ta montre n'a rien mesuré depuis 3 jours, et jamais une fois le check-in fait.",
                    bundle: .module))
            .font(.footnote)
            .foregroundStyle(PulsePalette.text2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
