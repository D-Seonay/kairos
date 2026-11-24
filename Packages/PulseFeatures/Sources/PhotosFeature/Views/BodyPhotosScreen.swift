import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import UniformTypeIdentifiers

/// L'écran Photos de corps, poussé depuis Profil : l'en-tête (« Sur cet iPhone seulement… », la dernière prise), une rangée par
/// jour avec les cases face, profil et dos, « Comparer avant / après », puis les réglages (verrou, export, tout supprimer). C'est la
/// racine de la section : il porte le verrou, le cache et les présentations (ajout, visionneuse, comparaison, export), qu'il ferme
/// toutes au reverrouillage.
public struct BodyPhotosScreen: View {
    @State private var model: BodyPhotosModel
    @State private var adding: BodyPhotoAddRequest?
    @State private var viewed: ViewedPhoto?
    @State private var compareModel: BodyPhotoCompareModel?
    @State private var showsCompare = false
    @State private var exportDocument: BodyPhotoArchive?
    @State private var showsExporter = false
    @State private var confirmsDeleteAll = false
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(service: BodyPhotoService, authentication: (any DeviceOwnerAuthenticating)?, lock: any BodyPhotoLockStore,
                calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.init(model: BodyPhotosModel(service: service, authentication: authentication, lock: lock, calendar: calendar, now: now))
    }

    init(model: BodyPhotosModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                header
                if model.lockState != .locked {
                    list
                    settings
                }
            }
            .padding(PulseMetrics.spacing)
        }
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(PhotoText.bodyTitle)
        .pulseInlineTitle()
        .toolbar {
            if !model.showsCover {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = BodyPhotoAddRequest(pose: .front) } label: {
                        Label(PhotoText.addPhoto, systemImage: "plus")
                    }
                }
            }
        }
        .bodyPhotoPrivacy(model, offersUnlock: true)
        .task { await model.appear() }
        .onAppear { model.screenAppeared() }
        .onDisappear { model.screenDisappeared() }
        .onChange(of: model.lockState) { _, state in
            if state == .locked { closePresentations() }
        }
        .onChange(of: model.announcementSerial) {
            if let text = model.announcement { PulseAnnouncement.post(text) }
        }
        .pulseAnnounceError(model.errorMessage)
        .sheet(item: $adding) { request in
            BodyPhotoAddSheet(model: model, request: request)
        }
        .photoViewerCover(item: $viewed) { viewed in
            if let photo = model.photos.first(where: { $0.id == viewed.id }) {
                BodyPhotoViewer(model: model, photo: photo)
            }
        }
        .navigationDestination(isPresented: $showsCompare) {
            if let compareModel {
                BodyPhotoCompareScreen(model: compareModel, photos: model)
            }
        }
        .fileExporter(isPresented: $showsExporter, document: exportDocument, contentTypes: [.zip],
                      defaultFilename: exportDocument?.url.lastPathComponent) { result in
            if case .failure(let error) = result {
                finishExport(failed: (error as? CocoaError)?.code != .userCancelled)
            } else {
                finishExport(failed: false)
            }
        } onCancellation: {
            finishExport(failed: false)
        }
        .confirmationDialog(PhotoText.deleteAllTitle, isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
            Button(PhotoText.deleteAllConfirm, role: .destructive) { Task { await model.deleteAll() } }
            Button(PhotoText.cancel, role: .cancel) {}
        } message: {
            Text(PhotoText.deleteAllMessage)
        }
    }

    // MARK: En-tête

    private var header: some View {
        ObsidianCard {
            HStack(alignment: .top, spacing: 12) {
                IconChip(systemName: "lock.fill", size: 36)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(model.headerLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(index == 0 ? .subheadline.weight(.semibold) : .footnote)
                            .foregroundStyle(index == 0 ? PulsePalette.text : PulsePalette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Liste

    @ViewBuilder
    private var list: some View {
        if let message = model.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(PulsePalette.bad)
                .fixedSize(horizontal: false, vertical: true)
        }
        if model.days.isEmpty {
            emptyState
        } else {
            ForEach(model.days) { day in
                BodyPhotoDayRow(model: model, day: day, columns: typeSize.isAccessibilitySize ? 2 : 3,
                                onOpen: { viewed = ViewedPhoto(id: $0.id) },
                                onAdd: { adding = BodyPhotoAddRequest(pose: $0) })
            }
            if model.canCompare {
                Button(PhotoText.compare, action: openCompare)
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                Text(PhotoText.compareNeedsTwoDates)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyState: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(PhotoText.emptyBodyTitle)
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
                Text(PhotoText.emptyBodyNote)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Button(PhotoText.addPhoto) { adding = BodyPhotoAddRequest(pose: .front) }
                    .buttonStyle(PillButtonStyle(prominent: true))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Réglages

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(PhotoText.settingsTitle)
            ObsidianCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(PhotoText.lockWithFaceID, isOn: lockBinding)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulsePalette.text)
                        .disabled(!model.hasPasscode || model.isAuthenticating)
                        .frame(minHeight: 44)
                    if !model.hasPasscode {
                        note(PhotoText.lockNeedsPasscode)
                    }
                    Divider().overlay(PulsePalette.line)
                    Button(action: startExport) {
                        HStack {
                            Label(PhotoText.export, systemImage: "folder")
                                .foregroundStyle(PulsePalette.text)
                            Spacer(minLength: 8)
                            if model.isExporting { ProgressView() }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.days.isEmpty || model.isExporting || model.isAuthenticating)
                    note(PhotoText.exportNote)
                    Divider().overlay(PulsePalette.line)
                    Button(role: .destructive) { confirmsDeleteAll = true } label: {
                        Text(PhotoText.deleteAll)
                            .foregroundStyle(PulsePalette.bad)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.days.isEmpty)
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(PulsePalette.text2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Couper le verrou demande Face ID : en cas d'échec, l'interrupteur revient sur sa position (la vue relit le modèle quand
    /// `isAuthenticating` retombe).
    private var lockBinding: Binding<Bool> {
        Binding(get: { model.isLockEnabled }, set: { on in Task { await model.setLockEnabled(on) } })
    }

    // MARK: Actions

    private func openCompare() {
        compareModel = model.makeCompareModel()
        showsCompare = true
    }

    /// Le sélecteur ne s'ouvre que si la section est toujours déverrouillée et à découvert ; sinon l'archive est abandonnée.
    private func startExport() {
        Task {
            guard let url = await model.exportArchive() else { return }
            exportDocument = BodyPhotoArchive(url: url)
            if model.lockState == .locked || model.isCovered {
                finishExport(failed: false)
            } else {
                showsExporter = true
            }
        }
    }

    private func finishExport(failed: Bool) {
        guard exportDocument != nil else { return }
        exportDocument = nil
        Task { await model.exportFinished(failed: failed) }
    }

    /// Au reverrouillage, tout ce qui est présenté se ferme : feuille d'ajout, visionneuse, comparaison et sélecteur d'export.
    private func closePresentations() {
        adding = nil
        viewed = nil
        showsCompare = false
        compareModel = nil
        confirmsDeleteAll = false
        showsExporter = false
        finishExport(failed: false)
    }
}

/// Une rangée de jour : la date, le nombre de photos et les cases face, profil, dos. Une case pleine ouvre la visionneuse ; une
/// case vide ajoute une photo de cette pose.
private struct BodyPhotoDayRow: View {
    let model: BodyPhotosModel
    let day: BodyPhotoDay
    let columns: Int
    let onOpen: (BodyPhoto) -> Void
    let onAdd: (BodyPose) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.dayTitle(day))
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(model.photoCountText(day))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(BodyPose.allCases, id: \.self) { pose in
                    slot(pose)
                }
            }
        }
    }

    @ViewBuilder
    private func slot(_ pose: BodyPose) -> some View {
        if let photo = day.photos[pose] {
            Button { onOpen(photo) } label: {
                PhotoSquare(data: model.thumbnails[photo.id])
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.spokenLabel(of: photo))
            .accessibilityHint(PhotoText.openPhotoHint)
        } else {
            Button { onAdd(pose) } label: {
                emptySlot(pose)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PhotoText.emptyPoseLabel(pose))
        }
    }

    /// La case vide d'une pose : un cadre en pointillés, un plus et le nom de la pose.
    private func emptySlot(_ pose: BodyPose) -> some View {
        let shape = RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
        return Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "plus").font(.title3.weight(.semibold))
                    Text(PhotoText.poseName(pose))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(PulsePalette.text2)
                .padding(4)
            }
            .overlay { shape.strokeBorder(PulsePalette.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
            .contentShape(shape)
    }
}

/// Une demande d'ajout : la pose proposée (celle de la case vide touchée, face depuis « + »).
struct BodyPhotoAddRequest: Identifiable {
    let id = UUID()
    let pose: BodyPose
}

/// L'archive d'export des photos de corps, pour le sélecteur d'emplacement de Fichiers (jamais la feuille de partage). Elle ne
/// se lit pas : Pulse ne fait que l'écrire. Le zip est lu d'un coup, avant que `exportFinished` ne supprime le fichier.
struct BodyPhotoArchive: FileDocument {
    static let readableContentTypes: [UTType] = [.zip]

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: .immediate)
    }
}

#if DEBUG
/// Prépare le modèle de l'aperçu, puis pousse l'écran.
private struct BodyPhotosPreviewHost: View {
    var lockEnabled = false
    var authentication = PreviewOwnerAuthentication()
    @State private var model: BodyPhotosModel?

    var body: some View {
        NavigationStack {
            if let model {
                BodyPhotosScreen(model: model)
            } else {
                ProgressView()
            }
        }
        .task { model = await BodyPhotosPreviewSupport.model(lockEnabled: lockEnabled, authentication: authentication) }
    }
}

#Preview("Photos de corps") {
    BodyPhotosPreviewHost()
}

#Preview("Photos de corps, accessibilité 3") {
    BodyPhotosPreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Photos de corps, verrouillées") {
    BodyPhotosPreviewHost(lockEnabled: true, authentication: PreviewOwnerAuthentication(succeeds: false))
}

#Preview("Photos de corps, sans code") {
    BodyPhotosPreviewHost(authentication: PreviewOwnerAuthentication(available: false))
}
#endif
