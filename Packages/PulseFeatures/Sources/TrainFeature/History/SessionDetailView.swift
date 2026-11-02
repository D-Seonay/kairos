import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le détail d'une séance passée (spec M4 §12), en lecture seule : le résumé, la carte musculaire, la note, puis les exercices et
/// leurs séries. « Enregistrer comme routine » ajoute la séance au programme et rend la main avec la routine à ouvrir ;
/// « Supprimer » demande confirmation. À présenter dans la pile de l'onglet « Séance ».
public struct SessionDetailView: View {
    @State private var model: SessionDetailModel
    @State private var confirmsDeletion = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    private let onRoutineSaved: (UUID, UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    /// `onRoutineSaved` reçoit le programme et la routine créés, pour ouvrir l'éditeur. Le modèle est gardé par l'écran :
    /// le premier reçu l'emporte, comme le veut `@State`.
    public init(model: SessionDetailModel, onRoutineSaved: @escaping (UUID, UUID) -> Void = { _, _ in }) {
        _model = State(initialValue: model)
        self.onRoutineSaved = onRoutineSaved
    }

    public var body: some View {
        Group {
            if model.isMissing {
                message(String(localized: "Cette séance est introuvable. Elle a peut-être été supprimée.", bundle: .module))
            } else if let session = model.session {
                list(session)
            } else if let failure = model.errorMessage {
                message(failure)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PulsePalette.background)
        .navigationTitle(model.session?.title ?? String(localized: "Séance", bundle: .module))
        .pulseInlineTitle()
        .confirmationDialog(String(localized: "Supprimer cette séance ?", bundle: .module), isPresented: $confirmsDeletion,
                            titleVisibility: .visible) {
            Button(String(localized: "Supprimer", bundle: .module), role: .destructive) { Task { await delete() } }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: {
            Text(String(localized: "Elle disparaît de ton historique et tes records sont recalculés.", bundle: .module))
        }
        .task { await model.load() }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text2)
            .padding(PulseMetrics.spacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func list(_ session: WorkoutSession) -> some View {
        List {
            if let failure = errorMessage {
                Section {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
            summary(session)
            if !model.muscleLevels.isEmpty {
                muscles
            }
            if let note = session.note, !note.isEmpty {
                Section {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text)
                } header: {
                    Text(String(localized: "Notes", bundle: .module))
                }
                .listRowBackground(PulsePalette.surface)
            }
            ForEach(model.blocks) { block in
                SessionBlockSection(block: block)
            }
            actions
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Sections

    private func summary(_ session: WorkoutSession) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.dateText)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                    if session.source == .hevy {
                        Badge(text: String(localized: "Hevy", bundle: .module), color: PulsePalette.text2)
                    }
                    if session.status == .abandoned {
                        Badge(text: String(localized: "Abandonnée", bundle: .module), color: PulsePalette.warn)
                    }
                }
                Text(model.summaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var muscles: some View {
        Section {
            MuscleMapView(levels: model.muscleLevels,
                          label: String(localized: "Muscles sollicités par la séance", bundle: .module), height: 220)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } header: {
            Text(String(localized: "Muscles sollicités", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var actions: some View {
        Section {
            Button { Task { await saveAsRoutine() } } label: {
                Label(String(localized: "Enregistrer comme routine", bundle: .module), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .disabled(!model.canSaveAsRoutine || isWorking)
            .accessibilityHint(String(localized: "Ajoute les exercices de cette séance à ton programme", bundle: .module))
            .accessibilityIdentifier(TrainIdentifiers.sessionSaveAsRoutine)
            Button(role: .destructive) { confirmsDeletion = true } label: {
                Label(String(localized: "Supprimer", bundle: .module), systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .disabled(isWorking)
            .accessibilityIdentifier(TrainIdentifiers.sessionDelete)
        }
        .listRowBackground(PulsePalette.surface)
    }

    // MARK: - Actions

    private func saveAsRoutine() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let saved = try await model.saveAsRoutine()
            errorMessage = nil
            onRoutineSaved(saved.programID, saved.dayID)
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer cette routine.", bundle: .module)
        }
    }

    private func delete() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await model.delete()
            dismiss()
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu supprimer cette séance.", bundle: .module)
        }
    }
}
