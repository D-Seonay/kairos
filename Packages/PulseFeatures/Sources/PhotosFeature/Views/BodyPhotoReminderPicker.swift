import PulseDesignSystem
import PulseServices
import SwiftUI

/// « Rappel de photo » dans les réglages des photos de corps : désactivé, toutes les 2 semaines ou tous les mois, et la note qui
/// dit ce que montre la notification, ou que les notifications sont coupées. Aux tailles d'accessibilité, le menu passe sous le
/// titre.
struct BodyPhotoReminderPicker: View {
    let model: BodyPhotosModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Text(PhotoText.reminderTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityHidden(true)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Picker(PhotoText.reminderTitle, selection: binding) {
                    ForEach(BodyPhotoReminderInterval.allCases, id: \.self) { interval in
                        Text(PhotoText.reminderInterval(interval)).tag(interval)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(PulsePalette.text2)
                .accessibilityLabel(PhotoText.reminderTitle)
            }
            .frame(minHeight: 44)
            Text(PhotoText.reminderNote)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
            if model.notificationsDenied {
                Text(PhotoText.reminderNotificationsOff)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.signal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Relue à l'apparition et au retour des réglages d'iOS.
        .task(id: scenePhase) {
            if scenePhase == .active { await model.refreshNotificationStatus() }
        }
    }

    private var binding: Binding<BodyPhotoReminderInterval> {
        Binding(get: { model.reminderInterval }, set: { interval in Task { await model.setReminderInterval(interval) } })
    }
}
