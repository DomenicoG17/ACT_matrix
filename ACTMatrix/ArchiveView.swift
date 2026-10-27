import SwiftUI
import UniformTypeIdentifiers

struct ArchiveView: View {
    @EnvironmentObject private var store: MatrixStore
    @Environment(\.dismiss) private var dismiss

    let onSelect: (UUID) -> Void
    let onNew: () -> Void

    @State private var renamingID: UUID?
    @State private var titleDraft = ""
    @State private var deletingID: UUID?
    @State private var showExport = false
    @State private var exportDocument: BackupDocument?
    @State private var showImport = false
    @State private var feedbackMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.matrices) { matrix in
                        Button {
                            onSelect(matrix.id)
                        } label: {
                            HStack(spacing: 14) {
                                quadrantThumbnail
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(matrix.displayTitle)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text("Creata il \(matrix.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(matrix.itemCount) punti")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if matrix.id == store.activeID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.teal)
                                        .accessibilityLabel("Matrice aperta")
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingID = matrix.id
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                            Button {
                                renamingID = matrix.id
                                titleDraft = matrix.title
                            } label: {
                                Label("Rinomina", systemImage: "pencil")
                            }
                            .tint(.indigo)
                        }
                    }
                } header: {
                    Text("Tutte le tue matrici · \(store.matrices.count)")
                } footer: {
                    Text("Le matrici si salvano automaticamente sul dispositivo. Puoi esportare un backup dal menu in alto.")
                }
            }
            .navigationTitle("Archivio ACT")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            do {
                                exportDocument = BackupDocument(data: try store.backupData())
                                showExport = true
                            } catch {
                                feedbackMessage = "Impossibile preparare il backup: \(error.localizedDescription)"
                            }
                        } label: {
                            Label("Esporta backup JSON", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            showImport = true
                        } label: {
                            Label("Importa backup JSON", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Backup: importa o esporta")

                    Button(action: onNew) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nuova matrice")
                }
            }
            .alert("Rinomina matrice", isPresented: Binding(
                get: { renamingID != nil },
                set: { if !$0 { renamingID = nil } }
            )) {
                TextField("Titolo", text: $titleDraft)
                Button("Annulla", role: .cancel) { renamingID = nil }
                Button("Salva") {
                    if let id = renamingID { store.rename(id, title: titleDraft) }
                    renamingID = nil
                }
            }
            .confirmationDialog(
                "Eliminare questa matrice?",
                isPresented: Binding(
                    get: { deletingID != nil },
                    set: { if !$0 { deletingID = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Elimina definitivamente", role: .destructive) {
                    if let id = deletingID { store.delete(id) }
                    deletingID = nil
                }
                Button("Annulla", role: .cancel) { deletingID = nil }
            } message: {
                Text("Non potrai recuperarla senza un backup esportato in precedenza.")
            }
            .fileExporter(
                isPresented: $showExport,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "ACTMatrix-backup"
            ) { result in
                if case .failure(let error) = result {
                    feedbackMessage = "Esportazione non riuscita: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [.json]
            ) { result in
                do {
                    let url = try result.get()
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                    let count = try store.importBackup(Data(contentsOf: url))
                    feedbackMessage = count == 0
                        ? "Nessuna nuova matrice da importare: sono già presenti."
                        : "Importate \(count) matrici. Quelle già presenti sono state conservate."
                } catch {
                    feedbackMessage = "Importazione non riuscita: \(error.localizedDescription)"
                }
            }
            .alert("Backup ACT", isPresented: Binding(
                get: { feedbackMessage != nil },
                set: { if !$0 { feedbackMessage = nil } }
            )) {
                Button("OK", role: .cancel) { feedbackMessage = nil }
            } message: {
                Text(feedbackMessage ?? "")
            }
        }
    }

    private var quadrantThumbnail: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                thumbnailCell.opacity(0.9)
                thumbnailCell.opacity(0.7)
            }
            HStack(spacing: 3) {
                thumbnailCell.opacity(0.7)
                thumbnailCell.opacity(0.9)
            }
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }

    private var thumbnailCell: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.teal.opacity(0.17))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.teal.opacity(0.5), lineWidth: 0.7)
            }
    }
}
