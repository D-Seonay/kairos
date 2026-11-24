import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'écran Compléments (spec M5 §10, maquette `supplements`) : la synthèse du jour et la prochaine prise, les moments et leurs
/// coches, les conseils, le stock et la régularité. À pousser dans une `NavigationStack` (accueil, profil).
public struct SupplementsView: View {
    private let model: SupplementsModel
    /// Le complément dont on confirme l'archivage (menu contextuel, action VoiceOver), comme dans le formulaire.
    @State private var archiving: Supplement?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// La colonne des noms des barres suit Dynamic Type ; un nom trop long passe à la ligne au lieu d'être coupé.
    @ScaledMetric(relativeTo: .subheadline) private var barTitleWidth: CGFloat = 110

    public init(model: SupplementsModel) {
        self.model = model
    }

    public var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: PulseMetrics.spacing) {
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !model.hasLoaded {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Chargement des compléments", bundle: .module))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if model.overview.supplements.isEmpty {
                    emptyState
                } else {
                    content
                }
                Text(SupplementLabels.disclaimer)
                    .font(.caption)
                    .foregroundStyle(PulsePalette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(PulseMetrics.spacing)
        }
        .refreshable { await model.load(announcesFailure: true) }
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(String(localized: "Compléments", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: model.startNew) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Ajouter un complément", bundle: .module))
                .accessibilityIdentifier(SupplementsIdentifiers.add)
            }
        }
        .sheet(item: $model.editor) { editor in
            NavigationStack {
                SupplementFormView(model: model, editing: editor.supplement)
            }
        }
        .supplementArchiveConfirmation($archiving) { supplement in
            Task { await model.archive(supplement) }
        }
        .task { await model.load(announcesFailure: true) }
    }

    @ViewBuilder
    private var content: some View {
        SupplementSummaryCard(model: model)
        ForEach(model.moments, id: \.moment) { entry in
            momentSection(entry.moment, items: entry.items)
        }
        if !model.notDueToday.isEmpty { notDueSection }
        if !model.overview.advice.isEmpty { adviceSection }
        if model.overview.supplements.contains(where: { $0.stockDoses != nil }) { stockSection }
        regularitySection
    }

    // MARK: Moments

    private func momentSection(_ moment: SupplementMoment, items: [SupplementDueItem]) -> some View {
        VStack(spacing: 8) {
            PulseSectionHeader(SupplementText.moment(moment)) {
                Image(systemName: SupplementLabels.momentIcon(moment))
                    .foregroundStyle(PulsePalette.text2)
                    .accessibilityHidden(true)
            }
            ObsidianCard {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        SupplementCheckRow(item: item, onToggle: { Task { await model.toggle(item) } },
                                           onOpen: { model.edit(item.supplement) },
                                           onArchive: { archiving = item.supplement })
                            .contextMenu { archiveButton(item.supplement) }
                    }
                }
            }
        }
    }

    private var notDueSection: some View {
        VStack(spacing: 8) {
            PulseSectionHeader(String(localized: "Pas prévu aujourd'hui", bundle: .module))
            ForEach(model.notDueToday) { supplement in
                Button { model.edit(supplement) } label: {
                    PulseRow(systemImage: "pills", title: supplement.name,
                             detail: "\(SupplementText.dose(of: supplement)) · \(SupplementLabels.days(supplement.days))")
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(SupplementsModel.notDueRowSpoken(supplement, days: SupplementLabels.days(supplement.days)))
                .accessibilityAction(named: String(localized: "Archiver", bundle: .module)) { archiving = supplement }
                .contextMenu { archiveButton(supplement) }
            }
        }
    }

    private func archiveButton(_ supplement: Supplement) -> some View {
        Button(role: .destructive) {
            archiving = supplement
        } label: {
            Label(String(localized: "Archiver", bundle: .module), systemImage: "archivebox")
        }
    }

    // MARK: Conseils, stock, régularité

    private var adviceSection: some View {
        VStack(spacing: 8) {
            ForEach(model.overview.advice) { advice in
                ObsidianCard {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(advice.title).font(.subheadline.weight(.semibold)).foregroundStyle(PulsePalette.text)
                            Text(advice.text).font(.footnote).foregroundStyle(PulsePalette.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } icon: {
                        Image(systemName: "lightbulb").foregroundStyle(PulsePalette.text2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var stockSection: some View {
        let tracked = model.overview.supplements.filter { $0.stockDoses != nil }
        let low = tracked.filter(\.isLowOnStock)
        return VStack(spacing: 8) {
            PulseSectionHeader(String(localized: "Stock", bundle: .module))
            ObsidianCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(tracked) { supplement in
                        let stock = supplement.stockDoses ?? 0
                        let fraction = Self.stockFraction(stock, threshold: supplement.lowStockThreshold)
                        bar(title: supplement.name, value: SupplementsModel.stockText(stock),
                            spokenValue: SupplementsModel.stockText(stock), fraction: fraction,
                            tint: supplement.isLowOnStock ? PulsePalette.bad : PulsePalette.text)
                    }
                    if !low.isEmpty {
                        Text(String(localized: "À racheter : \(low.map(\.name).formatted(.list(type: .and)))", bundle: .module))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PulsePalette.bad)
                    }
                }
            }
        }
    }

    private var regularitySection: some View {
        VStack(spacing: 8) {
            PulseSectionHeader(String(localized: "Régularité, 30 jours", bundle: .module))
            ObsidianCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.overview.supplements) { supplement in
                        let regularity = model.overview.regularity[supplement.id]
                        bar(title: supplement.name, value: SupplementsModel.rateText(regularity),
                            spokenValue: SupplementsModel.rateSpoken(regularity), fraction: regularity?.rate ?? 0, tint: PulsePalette.text)
                    }
                    Text(String(localized: "Jours pris sur jours prévus, depuis la création du complément.", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(PulsePalette.muted)
                }
            }
        }
    }

    /// Le nom, la barre et la valeur sur une ligne ; aux tailles d'accessibilité, le nom entier et la valeur au-dessus de la barre.
    @ViewBuilder
    private func bar(title: String, value: String, spokenValue: String, fraction: Double, tint: Color) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        barTitle(title)
                        Spacer(minLength: 8)
                        barValue(value)
                    }
                    track(fraction: fraction, tint: tint)
                }
            } else {
                HStack(spacing: 10) {
                    barTitle(title).frame(width: barTitleWidth, alignment: .leading)
                    track(fraction: fraction, tint: tint)
                    barValue(value).frame(minWidth: 56, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spokenValue)
    }

    private func barTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func barValue(_ value: String) -> some View {
        Text(value)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(PulsePalette.text)
    }

    private func track(fraction: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(PulsePalette.surface2)
                .overlay(alignment: .leading) {
                    Capsule().fill(tint).frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
        }
        .frame(height: 8)
    }

    /// Le remplissage de la barre de stock : plein à quatre fois le seuil (30 doses sans seuil).
    static func stockFraction(_ stock: Double, threshold: Double?) -> Double {
        let full = max(1, (threshold ?? 0) > 0 ? (threshold ?? 0) * 4 : 30)
        return stock / full
    }

    // MARK: État vide

    private var emptyState: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                IconChip(systemName: "pills", tone: .accent, size: 44)
                Text(String(localized: "Tes compléments, cochés en une touche", bundle: .module))
                    .font(PulseFont.title(.title3, weight: .semibold))
                    .foregroundStyle(PulsePalette.text)
                Text(String(localized: """
                    Ajoute ce que tu prends : Pulse te le rappelle au bon moment, suit ton stock et ta régularité, et écrit la \
                    vitamine D, le magnésium, la caféine et les protéines dans Apple Santé.
                    """, bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "Ajouter un complément", bundle: .module), action: model.startNew)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

/// « 2 sur 5 pris », les segments du jour et la prochaine prise avec « Pris ».
struct SupplementSummaryCard: View {
    let model: SupplementsModel
    /// Compte les prises réussies depuis « Pris » : chacune joue le retour de succès de la coche d'une ligne. La rangée de la
    /// prochaine prise change de complément après la touche, elle ne peut pas suivre son propre état.
    @State private var takes = 0

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.dateText)
                    .pulseEyebrow(PulsePalette.text2)
                if model.overview.dueCount == 0 {
                    Text(String(localized: "Rien de prévu aujourd'hui", bundle: .module))
                        .font(PulseFont.title(.title3, weight: .semibold))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(model.overview.takenCount)")
                            .font(PulseFont.value(.largeTitle))
                        Text(String(localized: "sur \(model.overview.dueCount) pris", bundle: .module))
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.text2)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SupplementsModel.summarySpoken(taken: model.overview.takenCount,
                                                                       due: model.overview.dueCount))
                    .accessibilityIdentifier(SupplementsIdentifiers.summary)
                    segments
                    if let next = model.overview.next {
                        NextIntakeRow(item: next) { take(next) }
                    } else {
                        Label(String(localized: "Tout est pris pour aujourd'hui.", bundle: .module), systemImage: "checkmark")
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.text2)
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: takes)
    }

    /// « Pris » : coche la prochaine prise ; le retour de succès ne part qu'une fois la prise enregistrée.
    private func take(_ item: SupplementDueItem) {
        Task {
            await model.toggle(item)
            if model.item(for: item.supplement.id)?.isTaken == true { takes += 1 }
        }
    }

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(model.overview.items) { item in
                Capsule()
                    .fill(item.isTaken ? PulsePalette.text : PulsePalette.surface2)
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// « Prochaine prise », le complément, sa dose et son heure, et « Pris ».
struct NextIntakeRow: View {
    let item: SupplementDueItem
    let onTake: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Le texte et « Pris » côte à côte ; aux tailles d'accessibilité, « Pris » sous le texte.
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Prochaine prise", bundle: .module))
                    .pulseEyebrow(PulsePalette.text2)
                Text(item.supplement.name)
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
                Text(SupplementsModel.detail(item))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(SupplementsModel.nextIntakeSpoken(item))
            Button(action: onTake) {
                Label(String(localized: "Pris", bundle: .module), systemImage: "checkmark")
            }
            .buttonStyle(PillButtonStyle(prominent: true))
            .accessibilityLabel(String(localized: "Marquer comme pris : \(item.supplement.name)", bundle: .module))
            .accessibilityIdentifier(SupplementsIdentifiers.cardTake)
        }
    }
}
