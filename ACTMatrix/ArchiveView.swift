import SwiftUI
import UniformTypeIdentifiers

private struct ACTDayGroup: Identifiable {
    let date: Date
    let matrices: [ACTMatrix]
    var id: Date { date }
}

private struct ACTMonthGroup: Identifiable {
    let date: Date
    let days: [ACTDayGroup]
    var id: Date { date }
    var count: Int { days.reduce(0) { $0 + $1.matrices.count } }
}

struct ArchiveView: View {
    @EnvironmentObject private var store: MatrixStore
    @Environment(\.dismiss) private var dismiss

    let onSelect: (UUID) -> Void
    let onNew: () -> Void

    @State private var expandedMonths: Set<Date> = []
    @State private var expandedDays: Set<Date> = []
    @State private var initializedTree = false
    @State private var renamingID: UUID?
    @State private var titleDraft = ""
    @State private var deletingID: UUID?
    @State private var showExport = false
    @State private var exportDocument: BackupDocument?
    @State private var showImport = false
    @State private var feedbackMessage: String?
    @State private var showSettings = false

    // The tree is grouped by CREATION date, not last-modified date.
    // Months and days are generated from the actual saved timestamps.
    private var monthGroups: [ACTMonthGroup] {
        let calendar = Calendar.autoupdatingCurrent
        let byMonth = Dictionary(grouping: store.matrices) { matrix in
            calendar.date(from: calendar.dateComponents([.year, .month], from: matrix.createdAt))
                ?? calendar.startOfDay(for: matrix.createdAt)
        }
        return byMonth.keys.sorted(by: >).map { month in
            let byDay = Dictionary(grouping: byMonth[month] ?? []) {
                calendar.startOfDay(for: $0.createdAt)
            }
            let days = byDay.keys.sorted(by: >).map { day in
                ACTDayGroup(date: day, matrices: (byDay[day] ?? []).sorted {
                    $0.createdAt > $1.createdAt
                })
            }
            return ACTMonthGroup(date: month, days: days)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(monthGroups) { month in
                        DisclosureGroup(isExpanded: Binding(
                            get: { expandedMonths.contains(month.id) },
                            set: { expanded in
                                if expanded { expandedMonths.insert(month.id) }
                                else { expandedMonths.remove(month.id) }
                            }
                        )) {
                            ForEach(month.days) { day in
                                DisclosureGroup(isExpanded: Binding(
                                    get: { expandedDays.contains(day.id) },
                                    set: { expanded in
                                        if expanded { expandedDays.insert(day.id) }
                                        else { expandedDays.remove(day.id) }
                                    }
                                )) {
                                    ForEach(day.matrices) { matrix in
                                        matrixRow(matrix)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .foregroundStyle(.secondary)
                                        Text(day.date.formatted(
                                            .dateTime.weekday(.wide).day().locale(Locale(identifier: "it_IT"))
                                        ))
                                            .font(.subheadline.weight(.medium))
                                        Spacer(minLength: 4)
                                        Text("\(day.matrices.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.teal)
                                Text(month.date.formatted(
                                    .dateTime.month(.wide).year().locale(Locale(identifier: "it_IT"))
                                ).capitalized)
                                    .font(.headline)
                                Spacer(minLength: 4)
                                Text("\(month.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Matrici create · \(store.matrices.count)")
                } footer: {
                    Text("Tocca un mese e poi un giorno per aprire le matrici. I dati restano sul dispositivo; usa il menu in alto per esportare un backup.")
                }
            }
            .navigationTitle("Le tue matrici")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                guard !initializedTree else { return }
                initializedTree = true
                // Show the newest day on entry; every other month/day can be expanded.
                if let latest = monthGroups.first {
                    expandedMonths.insert(latest.id)
                    if let latestDay = latest.days.first { expandedDays.insert(latestDay.id) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Impostazioni dell’app")
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
                        Button { showImport = true } label: {
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
            .sheet(isPresented: $showSettings) {
                ACTMatrixSettingsView()
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

    private func matrixRow(_ matrix: ACTMatrix) -> some View {
        Button {
            onSelect(matrix.id)
        } label: {
            HStack(spacing: 11) {
                quadrantThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(matrix.displayTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(matrix.createdAt.formatted(date: .omitted, time: .shortened)) · \(matrix.itemCount) punti")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if matrix.id == store.activeID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.teal)
                        .accessibilityLabel("Matrice aperta")
                }
            }
            .padding(.vertical, 4)
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
        .frame(width: 38, height: 38)
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

// Accessible from Home → gear. UserDefaults is intentionally local, so this
// display preference does not modify any matrix or its backup format.
private struct ACTMatrixSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showTapToWriteHint") private var showTapToWriteHint = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Mostra «Tocca per scrivere»", isOn: $showTapToWriteHint)
                } header: {
                    Text("Visualizzazione")
                } footer: {
                    Text("Se disattivato, i riquadri vuoti rimangono completamente bianchi. Puoi sempre toccarli per iniziare a scrivere.")
                }
                Section("Navigazione") {
                    Text("Nella vista completa, scorri in alto o in basso partendo dal centro della matrice o dal bordo laterale per passare alla matrice precedente o successiva. I singoli riquadri continuano a scorrere indipendentemente.")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }
}
