import PulseDesignSystem
import SwiftUI

/// La section « Photos » d'une séance : l'en-tête et « privées · 6 au maximum », la grille de vignettes (3 colonnes, 2 aux tailles
/// d'accessibilité) et la case « Ajouter », qui disparaît à 6. Un appui sur une vignette ouvre la visionneuse. À poser dans le
/// récap, le détail d'une séance ou d'une course ; elle charge ses photos à l'apparition et poste les annonces VoiceOver.
public struct SessionPhotosSection: View {
    private let model: SessionPhotosModel
    @State private var viewed: ViewedPhoto?
    @State private var cameraState = CameraAccess.current()
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(model: SessionPhotosModel) {
        self.model = model
    }

    public var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 10) {
                header
                grid
                if cameraState == .denied {
                    Text(PhotoText.cameraDeniedNote)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.signal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .trackingCameraState($cameraState)
        .photoAnnouncements(model)
        .task { await model.load() }
        .photoViewerCover(item: $viewed) { viewed in
            SessionPhotoViewer(model: model, startingAt: viewed.id)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            PulseSectionHeader(PhotoText.sectionTitle)
            Text(PhotoText.sectionNote)
                .pulseEyebrow()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 2 : 3)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(model.photos) { photo in
                Button { viewed = ViewedPhoto(id: photo.id) } label: {
                    PhotoSquare(data: model.thumbnails[photo.id])
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.spokenLabel(of: photo))
                .accessibilityHint(PhotoText.openPhotoHint)
            }
            if model.isAdding { pendingCell }
            if model.canAdd {
                AddPhotoMenu(model: model, cameraState: cameraState) { addCell }
                    .accessibilityLabel(PhotoText.addPhoto)
            }
        }
    }

    /// La case « Ajouter » : un cadre en pointillés, un plus et le mot.
    private var addCell: some View {
        let shape = RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "plus").font(.title3.weight(.semibold))
                    Text(PhotoText.addShort).font(.footnote.weight(.semibold))
                }
                .foregroundStyle(PulsePalette.text2)
            }
            .overlay { shape.strokeBorder(PulsePalette.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
            .contentShape(shape)
    }

    /// La case d'une photo en cours de traitement : elle ne bloque rien, on peut continuer la séance.
    private var pendingCell: some View {
        PhotoSquare(data: nil)
            .overlay { ProgressView() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PhotoText.addingPhoto)
    }
}

/// La photo ouverte dans la visionneuse.
struct ViewedPhoto: Identifiable {
    let id: UUID
}

#if DEBUG
#Preview("Photos de séance") {
    PhotosPreviewHost(count: 4) { SessionPhotosSection(model: $0).padding() }
}

#Preview("Photos, accessibilité 3") {
    PhotosPreviewHost(count: 3) { SessionPhotosSection(model: $0).padding() }
        .dynamicTypeSize(.accessibility3)
}

#Preview("Aucune photo") {
    PhotosPreviewHost(count: 0) { SessionPhotosSection(model: $0).padding() }
}

#Preview("Six photos") {
    PhotosPreviewHost(count: 6) { SessionPhotosSection(model: $0).padding() }
}
#endif
