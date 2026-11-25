import PulsePersistence
import SwiftUI

/// La section des rapports de plantage et de lenteur de l'écran Diagnostic : chaque rapport, et son bouton « Partager le
/// rapport » (feuille de partage, fichier JSON). Rien ne part sans ce bouton.
struct DiagnosticReportsSection: View {
    let model: DiagnosticReportsModel
    @State private var confirmsRemoval = false

    var body: some View {
        Section {
            if model.reports.isEmpty {
                Text(String(localized: "Aucun rapport pour l'instant."))
                    .foregroundStyle(.secondary)
            }
            ForEach(model.reports) { report in
                row(report)
            }
            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
            }
            if !model.reports.isEmpty {
                Button(String(localized: "Supprimer les rapports"), role: .destructive) { confirmsRemoval = true }
                    .frame(minHeight: 44)
            }
        } header: {
            Text(String(localized: "Plantages et lenteurs"))
        } footer: {
            Text(String(localized: """
                iOS livre ces rapports au plus une fois par jour, après un plantage, un blocage ou un lancement lent. Ils restent \
                sur cet iPhone, sans aucune donnée Santé, et ne partent que si tu les partages.
                """))
        }
        .task { await model.load() }
        .confirmationDialog(String(localized: "Supprimer les rapports ?"), isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button(String(localized: "Supprimer"), role: .destructive) { Task { await model.removeAll() } }
            Button(String(localized: "Annuler"), role: .cancel) {}
        }
    }

    private func row(_ report: DiagnosticReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DiagnosticReportsModel.title(report.summary)).font(.headline)
            Text(report.receivedAt, format: .dateTime.day().month(.wide).hour().minute())
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(DiagnosticReportsModel.details(report.summary), id: \.self) { line in
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ShareLink(item: report.fileURL, subject: Text(String(localized: "Rapport de diagnostic Pulse")),
                      message: Text(String(localized: "Rapport de diagnostic de Pulse (plantage, blocage ou lancement lent)."))) {
                Label(String(localized: "Partager le rapport"), systemImage: "square.and.arrow.up")
            }
            .frame(minHeight: 44)
        }
        .padding(.vertical, 4)
    }
}
