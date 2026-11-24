import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La comparaison avant / après, poussée depuis Photos de corps : la pose (seulement celles qui ont deux dates), la scène qui
/// superpose les deux photos avec un trait qu'on fait glisser (ou « Côte à côte »), l'écart, « Changer les dates » et la tuile du
/// poids. Le cache et le verrou sont ceux de la section : l'écran se ferme quand elle se reverrouille.
struct BodyPhotoCompareScreen: View {
    @Bindable var model: BodyPhotoCompareModel
    let photos: BodyPhotosModel
    @State private var showsDates = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                if model.poses.count > 1 {
                    Picker(PhotoText.pose, selection: $model.pose) {
                        ForEach(model.poses, id: \.self) { Text(PhotoText.poseName($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                }
                if let before = model.before, let after = model.after {
                    if model.isSideBySide {
                        sideBySide(before: before, after: after)
                    } else {
                        BodyPhotoCompareStage(model: model, photos: photos, before: before, after: after)
                    }
                    caption
                }
                actions
                weightTile
            }
            .padding(PulseMetrics.spacing)
        }
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(PhotoText.compareTitle)
        .pulseInlineTitle()
        .bodyPhotoPrivacy(photos)
        .onAppear {
            photos.screenAppeared()
            if voiceOverEnabled || typeSize.isAccessibilitySize { model.isSideBySide = true }
        }
        .onDisappear { photos.screenDisappeared() }
        .task(id: [model.before?.id, model.after?.id]) { await model.refreshWeightChange() }
        .onChange(of: photos.lockState) { _, state in
            if state == .locked { showsDates = false }
        }
        .sheet(isPresented: $showsDates) {
            BodyPhotoDatesSheet(model: model, photos: photos)
        }
    }

    /// Les deux photos sans superposition : côte à côte, en colonne aux tailles d'accessibilité.
    private func sideBySide(before: BodyPhoto, after: BodyPhoto) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            sidePhoto(before, tag: model.beforeTag)
            sidePhoto(after, tag: model.afterTag)
        }
    }

    private func sidePhoto(_ photo: BodyPhoto, tag: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BodyPhotoImage(model: photos, photoID: photo.id, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous))
            if let tag {
                Text(tag)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.spokenLabel(of: photo))
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var caption: some View {
        if let apart = model.apartText {
            Text(model.isSideBySide ? apart : PhotoText.dragToCompare(apart))
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtons }
            VStack(alignment: .leading, spacing: 8) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(model.isSideBySide ? PhotoText.overlay : PhotoText.sideBySide) { model.isSideBySide.toggle() }
            .buttonStyle(PillButtonStyle())
        if model.candidates.count > 2 {
            Button(PhotoText.changeDates) { showsDates = true }
                .buttonStyle(PillButtonStyle())
        }
    }

    @ViewBuilder
    private var weightTile: some View {
        if let text = model.weightText {
            VStack(alignment: .leading, spacing: 10) {
                ObsidianCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PhotoText.weightTrend)
                            .pulseEyebrow()
                        Text(text)
                            .font(PulseFont.value(.title))
                            .foregroundStyle(PulsePalette.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.weightSpoken ?? text)
                Text(PhotoText.noJudgement)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// La scène superposée : la photo d'après en fond, celle d'avant découverte jusqu'au trait vertical, qu'on fait glisser (ou qu'on
/// règle par pas de 10 % avec VoiceOver, balayer vers le haut ou le bas). Les étiquettes donnent les deux dates.
private struct BodyPhotoCompareStage: View {
    let model: BodyPhotoCompareModel
    let photos: BodyPhotosModel
    let before: BodyPhoto
    let after: BodyPhoto

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let x = width * model.position
            ZStack(alignment: .leading) {
                BodyPhotoImage(model: photos, photoID: after.id, contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                BodyPhotoImage(model: photos, photoID: before.id, contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .mask(alignment: .leading) { Rectangle().frame(width: x) }
                Rectangle()
                    .fill(PulsePalette.page)
                    .frame(width: 2)
                    .offset(x: x - 1)
                Circle()
                    .fill(PulsePalette.page)
                    .frame(width: 28, height: 28)
                    .overlay { Image(systemName: "arrow.left.and.right").font(.caption.weight(.bold)) }
                    .foregroundStyle(PulsePalette.ink)
                    .offset(x: x - 14)
            }
            .contentShape(Rectangle())
            // Simultané : un glissé vertical fait défiler l'écran, un glissé horizontal déplace le trait.
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard abs(value.translation.width) >= abs(value.translation.height) else { return }
                model.position = BodyPhotoCompareModel.clamped(value.location.x / width)
            })
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
        .overlay(alignment: .topLeading) { tag(model.beforeTag) }
        .overlay(alignment: .topTrailing) { tag(model.afterTag) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.sliderSpokenLabel)
        .accessibilityValue(model.sliderSpokenValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.increment()
            case .decrement: model.decrement()
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private func tag(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulsePalette.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PulsePalette.page.opacity(0.85), in: Capsule())
                .padding(8)
        }
    }
}

/// « Changer les dates » : deux listes des dates qui ont une photo de la pose.
private struct BodyPhotoDatesSheet: View {
    let model: BodyPhotoCompareModel
    let photos: BodyPhotosModel
    @State private var beforeID: UUID?
    @State private var afterID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    picker(PhotoText.before, selection: $beforeID)
                    picker(PhotoText.after, selection: $afterID)
                }
                .listRowBackground(PulsePalette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(PulsePalette.background)
            .navigationTitle(PhotoText.changeDates)
            .pulseInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PhotoText.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(PhotoText.done, action: apply)
                        .disabled(selected(beforeID) == nil || selected(afterID) == nil || beforeID == afterID)
                }
            }
        }
        .bodyPhotoPrivacy(photos)
        .presentationDetents([.medium, .large])
        .onAppear {
            beforeID = model.before?.id
            afterID = model.after?.id
        }
    }

    private func picker(_ title: String, selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            ForEach(model.candidates) { photo in
                Text(model.dateText(of: photo)).tag(Optional(photo.id))
            }
        }
        .frame(minHeight: 44)
    }

    private func selected(_ id: UUID?) -> BodyPhoto? {
        model.candidates.first { $0.id == id }
    }

    private func apply() {
        guard let before = selected(beforeID), let after = selected(afterID) else { return }
        Task {
            await model.choose(before: before, after: after)
            dismiss()
        }
    }
}

#if DEBUG
private struct ComparePreview: View {
    @State private var photos: BodyPhotosModel?
    @State private var compare: BodyPhotoCompareModel?

    var body: some View {
        NavigationStack {
            if let photos, let compare {
                BodyPhotoCompareScreen(model: compare, photos: photos)
            } else {
                ProgressView()
            }
        }
        .task {
            let photos = await BodyPhotosPreviewSupport.model()
            await photos.appear()
            compare = photos.makeCompareModel()
            self.photos = photos
        }
    }
}

#Preview("Comparer") {
    ComparePreview()
}

#Preview("Comparer, accessibilité 3") {
    ComparePreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
