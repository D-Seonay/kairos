import PhotosUI
import PulseDesignSystem
import PulseDomain
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// La feuille d'ajout d'une photo de corps : le conseil, la pose, puis « Prendre une photo » ou « Choisir dans Photos ». Une fois
/// l'image traitée, son aperçu et sa date, modifiable mais jamais après aujourd'hui. Si la pose a déjà une photo ce jour-là,
/// « Enregistrer » propose de la remplacer, avec confirmation.
struct BodyPhotoAddSheet: View {
    let model: BodyPhotosModel
    let request: BodyPhotoAddRequest
    @State private var pose: BodyPose
    @State private var draft: BodyPhotoDraft?
    @State private var takenAt = Date()
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var replaced: BodyPhoto?
    @State private var showsCamera = false
    @State private var showsPicker = false
    @State private var selection: PhotosPickerItem?
    @State private var cameraState = CameraAccess.current()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(model: BodyPhotosModel, request: BodyPhotoAddRequest) {
        self.model = model
        self.request = request
        _pose = State(initialValue: request.pose)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(PhotoText.addTip)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Picker(PhotoText.pose, selection: $pose) {
                        ForEach(BodyPose.allCases, id: \.self) { Text(PhotoText.poseName($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                }
                .listRowBackground(PulsePalette.surface)
                sourceSection
                if isProcessing || draft != nil {
                    draftSection
                }
                if let message = model.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.bad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .listRowBackground(PulsePalette.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulsePalette.background)
            .navigationTitle(PhotoText.addPhoto)
            .pulseInlineTitle()
            .toolbar { toolbar }
            .confirmationDialog(replaceTitle, isPresented: replacing, titleVisibility: .visible) {
                Button(PhotoText.replace, role: .destructive) { Task { await save() } }
                Button(PhotoText.cancel, role: .cancel) {}
            } message: {
                Text(PhotoText.replaceMessage)
            }
        }
        .bodyPhotoPrivacy(model)
        .trackingCameraState($cameraState)
        .photosPicker(isPresented: $showsPicker, selection: $selection, matching: .images)
        .onChange(of: selection) { _, item in importItem(item) }
        .cameraCover(isPresented: $showsCamera) { loader in Task { await prepare(loader) } }
        .onAppear { model.clearError() }
    }

    // MARK: Sections

    private var sourceSection: some View {
        Section {
            switch cameraState {
            case .available:
                sourceButton(PhotoText.takePhoto, systemImage: "camera") { showsCamera = true }
            case .denied:
                sourceButton(PhotoText.allowCamera, systemImage: "gearshape", action: openSettings)
            case .unavailable:
                EmptyView()
            }
            sourceButton(PhotoText.chooseFromLibrary, systemImage: "photo.on.rectangle") { showsPicker = true }
        }
        .disabled(isProcessing || isSaving)
        .listRowBackground(PulsePalette.surface)
    }

    private func sourceButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(PulsePalette.text)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var draftSection: some View {
        Section {
            if let draft {
                PhotoSquare(data: draft.processed.image.thumbnail)
                    .frame(maxWidth: 160)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                DatePicker(PhotoText.date, selection: $takenAt, in: ...model.today, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    .environment(\.calendar, model.calendar)
                    .environment(\.timeZone, model.calendar.timeZone)
                    .frame(minHeight: 44)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(PhotoText.preparingPhoto)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
            }
        }
        .listRowBackground(PulsePalette.surface)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(PhotoText.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(PhotoText.save) { Task { await confirmOrSave() } }
                .disabled(draft == nil || isSaving || model.showsCover)
        }
    }

    // MARK: Actions

    private var replacing: Binding<Bool> {
        Binding(get: { replaced != nil }, set: { if !$0 { replaced = nil } })
    }

    private var replaceTitle: String {
        guard let replaced else { return PhotoText.replace }
        return model.replaceTitle(replaced)
    }

    /// Passe l'image choisie dans Photos au traitement ; une image qui ne se charge pas compte comme illisible.
    private func importItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        selection = nil
        Task { await prepare { try? await item.loadTransferable(type: Data.self) } }
    }

    private func prepare(_ loader: @escaping @Sendable () async -> Data?) async {
        isProcessing = true
        draft = nil
        let data = await loader()
        let prepared = await model.prepare(data, day: request.day)
        isProcessing = false
        draft = prepared
        if let prepared { takenAt = prepared.takenAt }
    }

    /// Si la pose a déjà une photo ce jour-là, demande d'abord la confirmation du remplacement.
    private func confirmOrSave() async {
        if let existing = await model.photoToReplace(pose: pose, on: takenAt) {
            replaced = existing
        } else {
            await save()
        }
    }

    private func save() async {
        guard let draft, !isSaving else { return }
        isSaving = true
        let saved = await model.save(draft, pose: pose, takenAt: takenAt)
        isSaving = false
        if saved { dismiss() }
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        #endif
    }
}

#if DEBUG
private struct AddSheetPreview: View {
    @State private var model: BodyPhotosModel?

    var body: some View {
        Group {
            if let model {
                BodyPhotoAddSheet(model: model, request: BodyPhotoAddRequest(pose: .side, day: nil))
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

#Preview("Ajout d'une photo de corps") {
    AddSheetPreview()
}

#Preview("Ajout d'une photo de corps, accessibilité 3") {
    AddSheetPreview()
        .dynamicTypeSize(.accessibility3)
}
#endif
