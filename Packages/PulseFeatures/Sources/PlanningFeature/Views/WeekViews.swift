import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// La bande des 7 jours (maquette `planning`) : aujourd'hui en plein, un point plein pour un jour validé, creux pour un jour
/// prévu. Elle double la liste « Cette semaine » : l'appelant la plafonne à `...xxxLarge`, sept colonnes ne tiennent pas plus.
struct WeekStrip: View {
    let model: PlanningModel
    let onSelect: (PlanningDay) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.days) { day in
                Button { onSelect(day) } label: {
                    VStack(spacing: 4) {
                        Text(model.weekdayText(day))
                            .font(.caption2)
                        Text(model.dayNumber(day))
                            .font(.headline.monospacedDigit())
                        mark(day)
                    }
                    .foregroundStyle(day.isToday ? PulsePalette.page : PulsePalette.text)
                    .frame(minWidth: 44, maxWidth: .infinity, minHeight: 64)
                    .background {
                        RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny)
                            .fill(day.isToday ? PulsePalette.ink : PulsePalette.surface)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(model.accessibilityText(of: day))
                .accessibilityAddTraits(day.isToday ? .isSelected : [])
                .accessibilityIdentifier(PlanningIdentifiers.stripPrefix + model.dayNumber(day))
            }
        }
    }

    @ViewBuilder
    private func mark(_ day: PlanningDay) -> some View {
        let color = day.isToday ? PulsePalette.page : PulsePalette.ink
        switch day.state {
        case .done:
            Circle().fill(color).frame(width: 6, height: 6)
        case .planned:
            Circle().strokeBorder(color, lineWidth: 1).frame(width: 6, height: 6)
        case .missed, .rest, .mandatoryRest:
            Color.clear.frame(width: 6, height: 6)
        }
    }
}

/// La carte du jour : la séance et son lancement, « Séance faite » une fois validée, « Reprendre » pendant une séance.
struct TodayPlanCard: View {
    let model: PlanningModel
    let train: TrainModel
    let day: PlanningDay
    let onStart: () -> Void
    let onResume: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        OpalCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    IconChip(systemName: model.icon(of: day), tone: .inverted)
                    VStack(alignment: .leading, spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(heading(spoken: false))
                                .pulseEyebrow(PulsePalette.opalMuted)
                                .accessibilityLabel(heading(spoken: true))
                            Text(model.title(of: day))
                                .font(PulseFont.title(.title2, weight: .semibold))
                                .foregroundStyle(PulsePalette.opalInk)
                        }
                        // Aux tailles d'accessibilité, le badge passe sous le titre : à côté, il l'écraserait.
                        if isLightened, dynamicTypeSize.isAccessibilitySize { adjustedBadge }
                    }
                    Spacer(minLength: 0)
                    if isLightened, !dynamicTypeSize.isAccessibilitySize { adjustedBadge }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.opalMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if let reminder = model.spacingReminder(for: day) {
                    Label(reminder, systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.opalInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                action
            }
        }
        .accessibilityIdentifier(PlanningIdentifiers.todayCard)
    }

    private var isLightened: Bool {
        train.today?.isLightened == true && day.routine?.kind == .strength
    }

    private var adjustedBadge: some View {
        Text(String(localized: "Ajustée", bundle: .module))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().strokeBorder(PulsePalette.opalLine))
    }

    private func heading(spoken: Bool) -> String {
        PlanningText.todayHeading(weekday: model.weekdayName(day.date), number: model.dayNumber(day), spoken: spoken)
    }

    private var subtitle: String {
        if day.state == .done || day.scheduled.map(AntiInterference.isRule) == true { return model.detail(of: day) }
        if let routine = day.routine, routine.kind == .run { return PlanningText.run(routine) }
        return train.strengthSubtitle
    }

    @ViewBuilder
    private var action: some View {
        if let title = train.activeSessionTitle {
            Button(String(localized: "Reprendre « \(title) »", bundle: .module), action: onResume)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(PlanningIdentifiers.resume)
        } else if day.state == .done {
            Label(String(localized: "Séance faite", bundle: .module), systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.opalInk)
        } else if day.routine?.kind == .strength, train.launchToday() != nil {
            Button(String(localized: "Lancer la séance", bundle: .module), action: onStart)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(PlanningIdentifiers.start)
        }
    }
}

/// Un jour de la semaine en liste : date, séance, détail ; « Déplacer à… » sur un jour à venir.
struct WeekDayRow: View {
    let model: PlanningModel
    let day: PlanningDay
    /// Ouvre la séance faite ; `nil` sans séance faite.
    let onOpen: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var dateWidth: CGFloat = 40

    var body: some View {
        Group {
            if let onOpen {
                Button(action: onOpen) { row }
                    .buttonStyle(PressableButtonStyle())
            } else {
                row
            }
        }
        .contextMenu {
            if !model.targets(for: day).isEmpty {
                Button { model.moving = day } label: {
                    Label(String(localized: "Déplacer à…", bundle: .module), systemImage: "arrow.left.arrow.right")
                }
            }
            if model.canKeepPlanned(day) {
                Button { Task { await model.keepPlanned(day) } } label: {
                    Label(String(localized: "Garder le jour prévu", bundle: .module), systemImage: "arrow.uturn.backward")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.accessibilityText(of: day))
        .accessibilityAction(named: String(localized: "Déplacer", bundle: .module)) {
            if !model.targets(for: day).isEmpty { model.moving = day }
        }
        .accessibilityAction(named: String(localized: "Garder le jour prévu", bundle: .module)) {
            if model.canKeepPlanned(day) { Task { await model.keepPlanned(day) } }
        }
        .accessibilityIdentifier(PlanningIdentifiers.dayPrefix + model.dayNumber(day))
    }

    private var row: some View {
        ObsidianCard {
            HStack(spacing: 14) {
                dateAndTexts
                trailing
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .overlay {
            if day.isToday {
                RoundedRectangle(cornerRadius: PulseMetrics.radius).strokeBorder(PulsePalette.ink, lineWidth: 1.5)
            }
        }
    }

    /// La date, puis la séance et son détail : côte à côte, ou la date au-dessus aux tailles d'accessibilité.
    private var dateAndTexts: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            dateColumn(isLarge: isLarge)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title(of: day))
                    .font(.headline)
                    .foregroundStyle(day.state == .missed ? PulsePalette.text2 : PulsePalette.text)
                Text(model.detail(of: day))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func dateColumn(isLarge: Bool) -> some View {
        if isLarge {
            HStack(spacing: 8) {
                Text(model.weekdayText(day))
                    .font(.caption)
                    .foregroundStyle(PulsePalette.text2)
                Text(model.dayNumber(day))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PulsePalette.text)
            }
        } else {
            VStack(spacing: 0) {
                Text(model.weekdayText(day))
                    .font(.caption)
                    .foregroundStyle(PulsePalette.text2)
                Text(model.dayNumber(day))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(width: dateWidth)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if onOpen != nil {
            RowChevron()
        } else if day.state == .done {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(PulsePalette.ink).accessibilityHidden(true)
        } else if day.movedFrom != nil {
            Image(systemName: "arrow.left.arrow.right").foregroundStyle(PulsePalette.text2).accessibilityHidden(true)
        } else if day.scheduled.map(AntiInterference.isRule) == true {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(PulsePalette.text2).accessibilityHidden(true)
        }
    }
}
