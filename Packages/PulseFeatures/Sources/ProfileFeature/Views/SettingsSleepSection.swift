import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

// MARK: - Sommeil

/// L'objectif de sommeil, les réveils en semaine et le week-end, le rappel de coucher et son avance ; le pied donne le coucher
/// conseillé. Les choix de valeurs viennent de `SettingsModel` (afficher n'écrit rien), les textes de `ProfileText`.
struct SleepSettingsSection: View {
    let model: SettingsModel
    let profile: UserProfile

    var body: some View {
        Section {
            goal
            wake(weekend: false)
            wake(weekend: true)
            SettingsToggle(title: String(localized: "Rappel de coucher", bundle: .module),
                           isOn: model.notificationBinding(profile.bedtimeReminderEnabled) { $0.bedtimeReminderEnabled = $1 })
            if profile.bedtimeReminderEnabled { lead }
        } header: {
            Text(String(localized: "Sommeil", bundle: .module))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(ProfileText.advisedBedtime(weekday: model.sleepPlan?.bedtimeMinutes(weekend: false),
                                                weekend: model.sleepPlan?.bedtimeMinutes(weekend: true)))
                Text(String(localized: "L'objectif compte dans le score de sommeil dès le prochain calcul.", bundle: .module))
            }
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var goal: some View {
        let shown = SettingsModel.shownSleepGoal(profile)
        return Picker(selection: model.binding(shown) { $0.sleepGoalMinutes = $1 }) {
            ForEach(SettingsService.sleepGoalChoices, id: \.self) { Text(ProfileText.sleepGoal(minutes: $0)).tag($0) }
        } label: {
            Text(String(localized: "Objectif de sommeil", bundle: .module))
                .foregroundStyle(PulsePalette.text)
        }
        .pickerStyle(.menu)
        .tint(PulsePalette.text2)
        .accessibilityValue(ProfileText.sleepGoalSpoken(minutes: shown))
        .frame(minHeight: 44)
    }

    /// « Selon mes nuits (07:00) » ou « Heure choisie » ; avec une heure choisie, une ligne de plus porte l'heure.
    @ViewBuilder
    private func wake(weekend: Bool) -> some View {
        let title = weekend
            ? String(localized: "Réveil le week-end", bundle: .module)
            : String(localized: "Réveil en semaine", bundle: .module)
        let chosen = SettingsModel.chosenWake(profile, weekend: weekend)
        let habitual = weekend ? model.sleepPlan?.habitualWeekendWake : model.sleepPlan?.habitualWeekdayWake
        let chosenTitle = String(localized: "Heure choisie", bundle: .module)
        Picker(selection: Binding(get: { chosen != nil }, set: { isChosen in
            Task { await model.chooseWake(isChosen, weekend: weekend) }
        })) {
            Text(ProfileText.followsNights(habitual: habitual)).tag(false)
            Text(chosenTitle).tag(true)
        } label: {
            Text(title)
                .foregroundStyle(PulsePalette.text)
        }
        .pickerStyle(.menu)
        .tint(PulsePalette.text2)
        .accessibilityValue(chosen == nil ? ProfileText.followsNightsSpoken(habitual: habitual) : chosenTitle)
        .frame(minHeight: 44)
        if let chosen {
            DatePicker(selection: Binding(get: { model.wakeDate(chosen) }, set: { date in
                let minutes = model.wakeMinutes(of: date)
                Task { await model.setWake(minutes, weekend: weekend) }
            }), in: model.wakeDateRange, displayedComponents: .hourAndMinute) {
                Text(String(localized: "Heure de réveil", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .tint(PulsePalette.ink)
            .environment(\.calendar, model.environment.calendar)
            .environment(\.timeZone, model.environment.calendar.timeZone)
            .accessibilityLabel(title)
            .accessibilityValue(ProfileText.clockSpoken(minutes: chosen))
            .frame(minHeight: 44)
        }
    }

    private var lead: some View {
        let shown = SettingsModel.shownLead(profile)
        return Picker(selection: model.binding(shown) { $0.bedtimeReminderLeadMinutes = $1 }) {
            ForEach(SettingsService.bedtimeLeadChoices, id: \.self) { Text(ProfileText.bedtimeLead(minutes: $0)).tag($0) }
        } label: {
            Text(String(localized: "Prévenir", bundle: .module))
                .foregroundStyle(PulsePalette.text)
        }
        .pickerStyle(.menu)
        .tint(PulsePalette.text2)
        .accessibilityValue(ProfileText.bedtimeLeadSpoken(minutes: shown))
        .frame(minHeight: 44)
    }
}
