import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La visionneuse plein écran : on glisse d'une photo à l'autre, on partage l'image seule (la feuille de partage du système) et on
/// supprime avec confirmation. Fermer ramène à la section.
struct SessionPhotoViewer: View {
    let model: SessionPhotosModel
    @State private var currentID: UUID
    @State private var loaded: [UUID: LoadedPhoto] = [:]
    @State private var confirmsDelete = false
    @Environment(\.dismiss) private var dismiss

    init(model: SessionPhotosModel, startingAt photoID: UUID) {
        self.model = model
        _currentID = State(initialValue: photoID)
    }

    var body: some View {
        NavigationStack {
            pages
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PulsePalette.background.ignoresSafeArea())
                .navigationTitle(PhotoText.sectionTitle)
                .pulseInlineTitle()
                .toolbar { toolbar }
                .confirmationDialog(PhotoText.deleteTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button(PhotoText.delete, role: .destructive) { deleteCurrent() }
                    Button(PhotoText.cancel, role: .cancel) {}
                } message: {
                    Text(PhotoText.deleteMessage)
                }
        }
        .onChange(of: model.photos.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    @ViewBuilder
    private var pages: some View {
        #if os(iOS)
        TabView(selection: $currentID) {
            ForEach(model.photos) { photo in
                page(photo).tag(photo.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        #else
        if let photo = model.photos.first(where: { $0.id == currentID }) { page(photo) }
        #endif
    }

    private func page(_ photo: SessionPhoto) -> some View {
        Group {
            if let image = loaded[photo.id]?.image {
                image.resizable().scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.spokenLabel(of: photo))
        .accessibilityAddTraits(.isImage)
        .task(id: photo.id) { await load(photo.id) }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(PhotoText.close) { dismiss() }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let photo = loaded[currentID] {
                ShareLink(item: photo.shared, preview: SharePreview(PhotoText.share, image: photo.image)) {
                    Label(PhotoText.share, systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive) { confirmsDelete = true } label: {
                Label(PhotoText.delete, systemImage: "trash")
            }
        }
    }

    private func load(_ photoID: UUID) async {
        guard loaded[photoID] == nil, let data = await model.image(of: photoID), let image = Image(photoData: data) else { return }
        loaded[photoID] = LoadedPhoto(image: image, shared: SharedPhoto(data: data))
    }

    /// Supprime la photo affichée ; le pager passe à sa voisine, ou la visionneuse se ferme quand c'était la dernière.
    private func deleteCurrent() {
        let photos = model.photos
        guard let index = photos.firstIndex(where: { $0.id == currentID }) else { return }
        let removed = currentID
        let neighbour = photos.indices.contains(index + 1) ? photos[index + 1].id : (index > 0 ? photos[index - 1].id : nil)
        Task {
            if let neighbour { currentID = neighbour }
            await model.delete(removed)
            loaded[removed] = nil
        }
    }
}

/// Une image décodée et ses octets, prêts à partager.
private struct LoadedPhoto {
    let image: Image
    let shared: SharedPhoto
}

/// L'image seule, en JPEG : les octets déjà gardés (sans métadonnées), sans nouveau réencodage.
struct SharedPhoto: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { $0.data }
    }
}
