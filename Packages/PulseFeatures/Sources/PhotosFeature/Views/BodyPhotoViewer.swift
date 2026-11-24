import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La visionneuse d'une photo de corps, en plein écran : l'image et « Supprimer » (avec confirmation), rien d'autre. Ni partage,
/// ni copie, ni menu contextuel, ni glisser-déposer : une photo de corps ne quitte Pulse que par l'export des réglages.
struct BodyPhotoViewer: View {
    let model: BodyPhotosModel
    let photo: BodyPhoto
    @State private var confirmsDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BodyPhotoImage(model: model, photoID: photo.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.spokenLabel(of: photo))
                .accessibilityAddTraits(.isImage)
                .background(PulsePalette.background.ignoresSafeArea())
                .navigationTitle(model.spokenLabel(of: photo))
                .pulseInlineTitle()
                .toolbar { toolbar }
                .confirmationDialog(PhotoText.deleteTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button(PhotoText.delete, role: .destructive) { deletePhoto() }
                    Button(PhotoText.cancel, role: .cancel) {}
                } message: {
                    Text(PhotoText.bodyDeleteMessage)
                }
        }
        .bodyPhotoPrivacy(model)
        .onAppear { model.screenAppeared() }
        .onDisappear { model.screenDisappeared() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(PhotoText.close) { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(role: .destructive) { confirmsDelete = true } label: {
                Label(PhotoText.delete, systemImage: "trash")
            }
            .disabled(model.showsCover)
        }
    }

    private func deletePhoto() {
        Task {
            if await model.delete(photo.id) { dismiss() }
        }
    }
}

/// L'image entière d'une photo de corps, lue par le modèle, qui garde le verrou : un cercle pendant la lecture, un fond neutre si
/// elle ne se lit pas. Elle est oubliée dès que la section se reverrouille.
struct BodyPhotoImage: View {
    let model: BodyPhotosModel
    let photoID: UUID
    var contentMode: ContentMode = .fit
    @State private var image: Image?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                image.resizable().aspectRatio(contentMode: contentMode)
            } else if failed {
                PulsePalette.surface2
                    .overlay { Image(systemName: "photo").foregroundStyle(PulsePalette.muted) }
            } else {
                ProgressView()
            }
        }
        .task(id: photoID) { await load() }
        .onChange(of: model.lockState) { _, state in
            if state == .locked { image = nil }
        }
    }

    private func load() async {
        image = nil
        failed = false
        guard let data = await model.image(of: photoID), let decoded = Image(photoData: data) else {
            failed = true
            return
        }
        image = decoded
    }
}

#if DEBUG
private struct BodyViewerPreview: View {
    @State private var model: BodyPhotosModel?

    var body: some View {
        Group {
            if let model, let photo = model.photos.first {
                BodyPhotoViewer(model: model, photo: photo)
            } else {
                ProgressView()
            }
        }
        .task {
            let model = await BodyPhotosPreviewSupport.model()
            await model.appear()
            self.model = model
        }
    }
}

#Preview("Visionneuse, photo de corps") {
    BodyViewerPreview()
}

#Preview("Visionneuse, photo de corps, accessibilité 3") {
    BodyViewerPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
