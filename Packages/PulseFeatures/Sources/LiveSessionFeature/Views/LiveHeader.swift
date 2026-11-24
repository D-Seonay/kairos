import PhotosFeature
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'en-tête de la séance (spec M4 §14.2) : le chevron qui réduit l'écran (séance en direct seulement), le titre, « Terminer »,
/// le menu « Abandonner », puis la durée écoulée, le tonnage et les séries de travail faites sur prévues. Une séance passée
/// (§19.4) montre sa date, sa durée saisie, et « Annuler la saisie » à la place d'« Abandonner ». Avec `photos`, le bouton appareil photo précède le menu. Les confirmations sont celles
/// de l'appelant. Aux tailles d'accessibilité, les boutons passent sous le titre et les statistiques en colonne.
struct LiveHeader: View {
    let session: LiveSession
    let onFinish: () -> Void
    let onAbandon: () -> Void
    var calendar: Calendar = .current
    /// Les photos de la séance ; `nil` sans bouton photo (pas de service, saisie après coup, ou récap ouvert par-dessus).
    var photos: SessionPhotosModel?
    /// Réduit l'écran, la séance continue ; `nil` sans chevron (saisie après coup).
    var onMinimize: (() -> Void)?
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let isLarge = typeSize.isAccessibilitySize
        let titleRow = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
        let statsRow = isLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout())
        VStack(spacing: 4) {
            titleRow {
                HStack(spacing: 4) {
                    if let onMinimize { minimizeButton(onMinimize) }
                    Text(Self.titleText(session.title))
                        .font(PulseFont.title(.title3))
                        .foregroundStyle(PulsePalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack(spacing: 8) {
                    if let photos { LiveCameraButton(model: photos) }
                    menu
                    finishButton
                }
            }
            if let pastEndedAt = session.pastEndedAt {
                Text(Self.pastDateText(start: session.startedAt, end: pastEndedAt, calendar: calendar))
                    .accessibilityLabel(Self.pastDateSpokenText(start: session.startedAt, end: pastEndedAt, calendar: calendar))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            statsRow {
                if let pastEndedAt = session.pastEndedAt {
                    let minutes = Self.minutes(from: session.startedAt, to: pastEndedAt)
                    stat(String(localized: "Durée", bundle: .module), spoken: Self.durationSpokenText(minutes: minutes)) {
                        Text(PulseFormat.duration(minutes: minutes))
                    }
                } else {
                    // Le chrono visible se met à jour seul, avec les heures comme la Live Activity (« 1:15:12 ») ; VoiceOver
                    // dit la durée à la minute près.
                    TimelineView(.periodic(from: session.startedAt, by: 60)) { context in
                        stat(String(localized: "Durée", bundle: .module),
                             spoken: Self.elapsedSpokenText(from: session.startedAt, to: context.date), updatesFrequently: true) {
                            Text(timerInterval: session.startedAt...Date.distantFuture, pauseTime: nil, countsDown: false,
                                 showsHours: true)
                        }
                    }
                }
                stat(String(localized: "Tonnage", bundle: .module), spoken: Self.tonnageSpokenText(kg: session.tonnageKg),
                     numeric: session.tonnageKg) {
                    Text(Self.tonnageText(kg: session.tonnageKg))
                }
                stat(String(localized: "Séries", bundle: .module),
                     spoken: Self.progressAccessibilityText(done: session.doneWorkingSets, planned: session.plannedWorkingSets),
                     numeric: Double(session.doneWorkingSets)) {
                    Text(Self.progressText(done: session.doneWorkingSets, planned: session.plannedWorkingSets))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        // Une série validée fait rouler le tonnage et le compte des séries.
        .pulseAnimation(.snappy, value: session.tonnageKg)
        .pulseAnimation(.snappy, value: session.doneWorkingSets)
    }

    private var finishButton: some View {
        let palette = PulsePalette.accent(for: theme)
        return Button(action: onFinish) {
            Text(String(localized: "Terminer", bundle: .module))
                .font(PulseFont.title(.subheadline))
                .foregroundStyle(Color(palette.accentInk))
                .padding(.horizontal, 18)
                .frame(minHeight: LiveSetRow.targetHeight)
                .background(Color(palette.accent), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(LiveSessionIdentifiers.finishButton)
    }

    /// Le chevron qui réduit l'écran, comme celui de la course : la séance continue et le bandeau « Reprendre » la rouvre.
    private func minimizeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulsePalette.text2)
                .frame(width: LiveSetRow.targetHeight, height: LiveSetRow.targetHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Réduire la séance", bundle: .module))
        .accessibilityHint(String(localized: "La séance continue en arrière-plan", bundle: .module))
        .accessibilityIdentifier(LiveSessionIdentifiers.minimizeButton)
    }

    private var menu: some View {
        Menu {
            Button(role: .destructive, action: onAbandon) {
                Label(session.isPastEntry ? String(localized: "Annuler la saisie", bundle: .module)
                        : String(localized: "Abandonner", bundle: .module), systemImage: "xmark.circle")
            }
            .accessibilityIdentifier(LiveSessionIdentifiers.abandonButton)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundStyle(PulsePalette.text2)
                .frame(width: LiveSetRow.targetHeight, height: LiveSetRow.targetHeight)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Menu de la séance", bundle: .module))
        .accessibilityIdentifier(LiveSessionIdentifiers.menuButton)
    }

    /// Une statistique : VoiceOver lit son nom puis `spoken`. `numeric` fait rouler les chiffres quand la valeur change ;
    /// `updatesFrequently` pour la durée qui court.
    private func stat(_ name: String, spoken: String, numeric: Double? = nil, updatesFrequently: Bool = false,
                      @ViewBuilder value: () -> some View) -> some View {
        let isLarge = typeSize.isAccessibilitySize
        return VStack(alignment: isLarge ? .leading : .center, spacing: 0) {
            Text(name).pulseEyebrow()
            Group {
                if let numeric {
                    value().pulseNumericTransition(value: numeric)
                } else {
                    value()
                }
            }
            .font(PulseFont.value(.title2))
            .foregroundStyle(PulsePalette.text)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: isLarge ? .leading : .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(spoken)
        .accessibilityAddTraits(updatesFrequently ? .updatesFrequently : [])
    }
}

// MARK: - Textes

extension LiveHeader {
    /// Le titre de la séance ; « Séance » quand elle n'en a pas.
    nonisolated static func titleText(_ title: String) -> String {
        title.isEmpty ? String(localized: "Séance", bundle: .module) : title
    }

    /// « 4 / 14 » : les séries de travail faites sur prévues.
    nonisolated static func progressText(done: Int, planned: Int) -> String {
        "\(done) / \(planned)"
    }

    /// « 4 séries faites sur 14 ».
    nonisolated static func progressAccessibilityText(done: Int, planned: Int) -> String {
        done == 1 ? String(localized: "1 série faite sur \(planned)", bundle: .module)
            : String(localized: "\(done) séries faites sur \(planned)", bundle: .module)
    }

    /// « Mercredi 28 octobre · 18:00 – 19:05 », en heure du calendrier de l'app.
    nonisolated static func pastDateText(start: Date, end: Date, calendar: Calendar) -> String {
        let locale = Locale(identifier: "fr_FR")
        let day = start.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).day().month(.wide))
        let time = { (date: Date) in FinishFlowModel.timeText(date, calendar: calendar) }
        return "\(day.prefix(1).uppercased())\(day.dropFirst()) · \(time(start)) – \(time(end))"
    }

    /// « Mercredi 28 octobre, de 18 heures à 19 heures 5 » : `pastDateText` dit en mots.
    nonisolated static func pastDateSpokenText(start: Date, end: Date, calendar: Calendar) -> String {
        let weekday = PulseSpoken.weekday(start, calendar: calendar)
        let day = "\(weekday.prefix(1).uppercased())\(weekday.dropFirst()) \(PulseSpoken.date(start, calendar: calendar))"
        let clock = { (date: Date) in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return PulseSpoken.clock(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        }
        return String(localized: "\(day), de \(clock(start)) à \(clock(end))", bundle: .module)
    }

    /// La durée saisie, en minutes arrondies.
    nonisolated static func minutes(from start: Date, to end: Date) -> Int {
        Int((max(0, end.timeIntervalSince(start)) / 60).rounded())
    }

    /// « 1 240 kg », « 62,5 kg ».
    nonisolated static func tonnageText(kg: Double) -> String {
        String(localized: "\(PulseFormat.grouped(kg, maxFractionDigits: 1)) kg", bundle: .module)
    }

    /// « 1 240 kilos ».
    nonisolated static func tonnageSpokenText(kg: Double) -> String {
        PulseSpoken.kilos((kg * 10).rounded() / 10)
    }

    /// « 1 heure 5 minutes » : la durée saisie d'une séance passée.
    nonisolated static func durationSpokenText(minutes: Int) -> String {
        PulseSpoken.duration(seconds: max(0, minutes) * 60)
    }

    /// « 12 minutes » : la durée écoulée à la minute près ; « Moins d'une minute » au début.
    nonisolated static func elapsedSpokenText(from start: Date, to now: Date) -> String {
        let minutes = Int(max(0, now.timeIntervalSince(start)) / 60)
        guard minutes > 0 else { return String(localized: "Moins d'une minute", bundle: .module) }
        return durationSpokenText(minutes: minutes)
    }
}
