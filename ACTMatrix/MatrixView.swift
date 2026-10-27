import SwiftUI

struct MatrixView: View {
    @EnvironmentObject private var store: MatrixStore
    @State private var selectedQuadrant: Int?
    @State private var focusToken = 0
    @State private var showArchive = false
    @State private var showRename = false
    @State private var titleDraft = ""

    private let gap: CGFloat = 9
    private let focusScale: CGFloat = 1.78

    private let headings = [
        "Azioni di allontanamento",
        "Azioni di avvicinamento",
        "Pensieri ed emozioni",
        "Persone e valori"
    ]
    private let subtitles = [
        "Ciò che faccio per evitare",
        "Passi verso ciò che conta",
        "Ciò che si presenta dentro di me",
        "Chi e cosa è importante"
    ]
    private let symbols = [
        "arrow.up.left", "arrow.up.right", "heart.text.square", "heart"
    ]
    private let accents: [Color] = [
        Color(red: 0.66, green: 0.43, blue: 0.35),
        Color(red: 0.27, green: 0.52, blue: 0.47),
        Color(red: 0.49, green: 0.49, blue: 0.67),
        Color(red: 0.33, green: 0.48, blue: 0.64)
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, 8)

            GeometryReader { geometry in
                let zoomed = selectedQuadrant != nil
                let scale = zoomed ? focusScale : 1
                let width = geometry.size.width
                let height = geometry.size.height
                let xOffset = selectedQuadrant.map { $0 % 2 == 1 ? -width * (scale - 1) : 0 } ?? 0
                let yOffset = selectedQuadrant.map { $0 >= 2 ? -height * (scale - 1) : 0 } ?? 0

                board(width: width * scale, height: height * scale)
                    .offset(x: xOffset, y: yOffset)
                    .animation(.spring(response: 0.38, dampingFraction: 0.87), value: selectedQuadrant)
                    .frame(width: width, height: height, alignment: .topLeading)
                    .clipped()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .fullScreenCover(isPresented: $showArchive) {
            ArchiveView { matrixID in
                store.activate(matrixID)
                selectedQuadrant = nil
                showArchive = false
            } onNew: {
                createNewMatrix()
                showArchive = false
            }
            .environmentObject(store)
        }
        .alert("Rinomina matrice", isPresented: $showRename) {
            TextField("Titolo (facoltativo)", text: $titleDraft)
            Button("Annulla", role: .cancel) { }
            Button("Salva") {
                store.rename(store.activeID, title: titleDraft)
            }
        } message: {
            Text("Un titolo può aiutarti a ritrovare questa matrice nell’archivio.")
        }
        .alert("Errore di salvataggio", isPresented: Binding(
            get: { store.saveError != nil },
            set: { if !$0 { store.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { store.saveError = nil }
        } message: {
            Text(store.saveError ?? "")
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                selectedQuadrant = nil  // Dismiss keyboard before entering the home screen.
                showArchive = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 38, height: 44)
            }
            .accessibilityLabel("Home: tutte le matrici")

            Button {
                titleDraft = store.activeMatrix.title
                showRename = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.activeMatrix.title.isEmpty ? "ACT Matrix" : store.activeMatrix.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(store.activeMatrix.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rinomina questa matrice")

            if selectedQuadrant != nil {
                Button {
                    selectedQuadrant = nil
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 38, height: 44)
                }
                .accessibilityLabel("Mostra tutta la matrice")
            }

            Button(action: createNewMatrix) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 38, height: 44)
            }
            .accessibilityLabel("Crea nuova matrice")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 5)
    }

    private func board(width: CGFloat, height: CGFloat) -> some View {
        let tileWidth = max(1, (width - gap) / 2)
        let tileHeight = max(1, (height - gap) / 2)
        return VStack(spacing: gap) {
            HStack(spacing: gap) {
                tile(0).frame(width: tileWidth, height: tileHeight)
                tile(1).frame(width: tileWidth, height: tileHeight)
            }
            HStack(spacing: gap) {
                tile(2).frame(width: tileWidth, height: tileHeight)
                tile(3).frame(width: tileWidth, height: tileHeight)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func tile(_ quadrant: Int) -> some View {
        let selected = selectedQuadrant == quadrant
        let entries = store.entries(in: quadrant)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: symbols[quadrant])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accents[quadrant])
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(headings[quadrant])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accents[quadrant])
                            .fixedSize(horizontal: false, vertical: true)
                        if selected {
                            Text(subtitles[quadrant])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 3)

                if selected {
                    BulletedEditor(
                        entries: Binding(
                            get: { store.entries(in: quadrant) },
                            set: { store.updateEntries($0, in: quadrant) }
                        ),
                        focusToken: focusToken,
                        currentQuadrant: quadrant,
                        onNavigate: { destination in
                            openQuadrant(destination, addBlank: true)
                        },
                        onNew: createNewMatrix,
                        onShowAll: { selectedQuadrant = nil }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    preview(entries)
                }
            }
            .padding(13)

        }
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(
                    accents[quadrant].opacity(selected ? 0.62 : 0.17),
                    lineWidth: selected ? 1.5 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        // Simultaneous tap doesn't steal the vertical drag from the inner ScrollView.
        .simultaneousGesture(TapGesture().onEnded {
            if !selected { openQuadrant(quadrant, addBlank: true) }
        })
    }

    @ViewBuilder
    private func preview(_ entries: [ACTEntry]) -> some View {
        let nonempty = entries.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        if nonempty.isEmpty {
            Text("Tocca per scrivere…")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(nonempty.indices, id: \.self) { entryIndex in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(nonempty[entryIndex].kind.symbol)
                            Text(nonempty[entryIndex].text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func openQuadrant(_ quadrant: Int, addBlank: Bool) {
        if addBlank { store.prepareNewBullet(in: quadrant) }
        selectedQuadrant = quadrant
        focusToken += 1
    }

    private func createNewMatrix() {
        selectedQuadrant = nil
        store.createMatrix()
    }
}
