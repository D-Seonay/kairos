import PulseDesignSystem
import SwiftUI

/// L'icône appareil photo de l'en-tête de la séance live, avec le nombre de photos en badge. Un appui propose « Prendre une photo »
/// ou « Choisir dans Photos » ; à 6 photos, elle est grisée. Elle poste les annonces du modèle : ne pas la mettre avec une
/// `SessionPhotosSection` sur le même écran.
public struct LiveCameraButton: View {
    private let model: SessionPhotosModel
    @State private var cameraState = CameraAccess.current()

    public init(model: SessionPhotosModel) {
        self.model = model
    }

    public var body: some View {
        AddPhotoMenu(model: model, cameraState: cameraState) {
            IconChip(systemName: "camera", size: 44)
                .overlay(alignment: .topTrailing) { badge }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(!model.canAdd)
        .accessibilityLabel(PhotoText.liveButtonLabel(count: model.photos.count))
        .trackingCameraState($cameraState)
        .photoAnnouncements(model)
        .task { await model.load() }
    }

    @ViewBuilder
    private var badge: some View {
        if !model.photos.isEmpty {
            Text("\(model.photos.count)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(PulsePalette.page)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(PulsePalette.ink, in: Capsule())
                .offset(x: 4, y: -4)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("Bouton photo, 0 photo") {
    PhotosPreviewHost(count: 0) { LiveCameraButton(model: $0).padding() }
}

#Preview("Bouton photo, 6 photos") {
    PhotosPreviewHost(count: 6) { LiveCameraButton(model: $0).padding() }
}

#Preview("Bouton photo, 0 photo, accessibilité 3") {
    PhotosPreviewHost(count: 0) { LiveCameraButton(model: $0).padding() }
        .dynamicTypeSize(.accessibility3)
}

#Preview("Bouton photo, 6 photos, accessibilité 3") {
    PhotosPreviewHost(count: 6) { LiveCameraButton(model: $0).padding() }
        .dynamicTypeSize(.accessibility3)
}
#endif
