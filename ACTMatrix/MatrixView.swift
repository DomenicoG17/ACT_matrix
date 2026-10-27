import SwiftUI

private struct TodoNoteRoute: Identifiable {
    let id: UUID
}

struct MatrixView: View {
    @EnvironmentObject private var store: MatrixStore
    @State private var selectedQuadrant: Int?
    @State private var focusToken = 0
    @State private var showArchive = false
    @State private var showRename = false
    @State private var titleDraft = ""
    @State private var showTodos = false
    @State private var noteRoute: TodoNoteRoute?

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

                if showTodos {
                    TodoOverview(onOpenNote: { id in noteRoute = TodoNoteRoute(id: id) })
                        .frame(width: width, height: height)
                        .transition(.move(edge: .trailing))
                } else {
                    board(width: width * scale, height: height * scale)
                        .offset(x: xOffset, y: yOffset)
                        .animation(.spring(response: 0.38, dampingFraction: 0.87), value: selectedQuadrant)
                        .frame(width: width, height: height, alignment: .topLeading)
                        .clipped()
                        .transition(.move(edge: .leading))
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .overlay(alignment: .trailing) {
            if !showTodos && selectedQuadrant == nil {
                Color.clear.frame(width: 26).padding(.top, 62).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 28).onEnded { drag in
                        if drag.translation.width < -55 && abs(drag.translation.height) < 100 {
                            withAnimation(.easeInOut(duration: 0.25)) { showTodos = true }
                        }
                    })
            }
        }
        .overlay(alignment: .leading) {
            if showTodos {
                Color.clear.frame(width: 26).padding(.top, 62).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 28).onEnded { drag in
                        if drag.translation.width > 55 && abs(drag.translation.height) < 100 {
                            withAnimation(.easeInOut(duration: 0.25)) { showTodos = false }
                        }
                    })
            }
        }
        .fullScreenCover(item: $noteRoute) { route in
            TodoNotePage(entryID: route.id,
                         onClose: { noteRoute = nil },
                         onShowAll: { noteRoute = nil; selectedQuadrant = nil; showTodos = false },
                         onNavigate: { quadrant in
                             noteRoute = nil
                             showTodos = false
                             DispatchQueue.main.async { openQuadrant(quadrant, addBlank: true) }
                         },
                         onNew: {
                             noteRoute = nil
                             showTodos = false
                             createNewMatrix()
                         })
            .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showArchive) {
            ArchiveView { matrixID in
                store.activate(matrixID)
                selectedQuadrant = nil
                showTodos = false
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

            Button {
                selectedQuadrant = nil
                withAnimation(.easeInOut(duration: 0.25)) { showTodos.toggle() }
            } label: {
                Image(systemName: showTodos ? "square.grid.2x2" : "checklist")
                    .font(.system(size: 20))
                    .frame(width: 35, height: 44)
            }
            .accessibilityLabel(showTodos ? "Torna alla matrice" : "Mostra tutti i to-do")

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
                // Also accept taps on the tile margins when it already contains entries.
                // Interactive rows (notes, recurrence buttons and drag targets) remain above.
                .onTapGesture {
                    if !selected { openQuadrant(quadrant, addBlank: true) }
                }

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
                .contentShape(Rectangle())
                .onTapGesture {
                    if !selected { openQuadrant(quadrant, addBlank: true) }
                }

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
                        onShowAll: { selectedQuadrant = nil },
                        onAdjustRecurrence: { index, delta in
                            store.adjustRecurrence(in: quadrant, at: index, by: delta)
                        },
                        onOpenTodo: { entryID in
                            noteRoute = TodoNoteRoute(id: entryID)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    preview(entries, quadrant: quadrant)
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
        // Only text/empty space activates zoom. A counter tap must NOT zoom.
    }

    @ViewBuilder
    private func preview(_ entries: [ACTEntry], quadrant: Int) -> some View {
        let visible = entries.indices.filter {
            !entries[$0].text.trimmingCharacters(in: .whitespaces).isEmpty
        }
        if visible.isEmpty {
            Text("Tocca per scrivere…")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { openQuadrant(quadrant, addBlank: true) }
        } else {
            // The content covers at least the scroll viewport. Its transparent
            // background is tappable, including the space UNDER existing rows.
            // A tap on a recurrence control or a to-do link still uses that
            // control's own action, rather than entering editing mode.
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(visible, id: \.self) { index in
                            HStack(alignment: .top, spacing: 4) {
                                Text(entries[index].indentLevel > 0 ? "↳" : entries[index].kind.symbol)
                                Text(entries[index].text)
                                    .foregroundStyle(entries[index].kind == .todo ? Color.blue : Color.primary)
                                    .underline(entries[index].kind == .todo)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if entries[index].kind == .todo {
                                            noteRoute = TodoNoteRoute(id: entries[index].id)
                                        } else {
                                            openQuadrant(quadrant, addBlank: true)
                                        }
                                    }
                                recurrenceControls(
                                    count: entries[index].recurrenceCount,
                                    quadrant: quadrant,
                                    index: index
                                )
                            }
                            .font(.system(size: 13))
                            .padding(.leading, CGFloat(entries[index].indentLevel) * 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .draggable(entries[index].id.uuidString)
                            .dropDestination(for: String.self) { values, location in
                                guard let first = values.first,
                                      let id = UUID(uuidString: first) else { return false }
                                store.moveEntry(in: quadrant, sourceID: id,
                                                to: entries[index].id, after: location.y > 18)
                                return true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: viewport.size.height, alignment: .topLeading)
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { openQuadrant(quadrant, addBlank: true) }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func recurrenceControls(count: Int, quadrant: Int, index: Int) -> some View {
        HStack(spacing: 2) {
            if count > 0 {
                Button {
                    store.adjustRecurrence(in: quadrant, at: index, by: -1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .frame(width: 19, height: 24)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Diminuisci ricorrenze")
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("\(count) ricorrenze")
            }
            Button {
                store.adjustRecurrence(in: quadrant, at: index, by: 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .frame(width: 19, height: 24)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Aumenta ricorrenze")
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func openQuadrant(_ quadrant: Int, addBlank: Bool) {
        if addBlank { store.prepareNewBullet(in: quadrant) }
        showTodos = false
        selectedQuadrant = quadrant
        focusToken += 1
    }

    private func createNewMatrix() {
        selectedQuadrant = nil
        showTodos = false
        store.createMatrix()
    }
}

// All to-do entries from the CURRENT matrix. Reordering here never moves the
// original quadrant entries; the store saves a separate list of stable UUIDs.
private struct TodoOverview: View {
    @EnvironmentObject private var store: MatrixStore
    let onOpenNote: (UUID) -> Void

    var body: some View {
        let todos = store.allTodos()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Da fare")
                            .font(.largeTitle.weight(.bold))
                        Text("\(todos.count) voci · trascina per riordinare")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 25))
                        .foregroundStyle(.teal)
                }
                .padding(.top, 9)

                if todos.isEmpty {
                    ContentUnavailableView("Nessun to-do", systemImage: "checklist",
                                           description: Text("Seleziona 🔲 su una voce della matrice per aggiungerla qui."))
                        .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 9) {
                        ForEach(todos) { item in
                            todoRow(item)
                                .draggable(item.id.uuidString)
                                .dropDestination(for: String.self) { values, location in
                                    guard let value = values.first,
                                          let source = UUID(uuidString: value) else { return false }
                                    store.moveTodo(sourceID: source, to: item.id,
                                                   after: location.y > 32)
                                    return true
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func todoRow(_ entry: ACTEntry) -> some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("🔲")
            Button { onOpenNote(entry.id) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.text)
                        .foregroundStyle(Color.blue)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("Appunti presenti", systemImage: "note.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 15))
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 15))
    }
}

// A white, persistent note page for each to-do. It deliberately reuses the
// same MatrixKeyboardBar as the main editor, including icons and indentation.
private struct TodoNotePage: View {
    @EnvironmentObject private var store: MatrixStore
    let entryID: UUID
    let onClose: () -> Void
    let onShowAll: () -> Void
    let onNavigate: (Int) -> Void
    let onNew: () -> Void

    private var noteBinding: Binding<String> {
        Binding(get: { store.entry(withID: entryID)?.note ?? "" },
                set: { store.updateNote($0, for: entryID) })
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.entry(withID: entryID)?.text ?? "To-do")
                    .foregroundStyle(.blue)
                    .underline()
                    .font(.subheadline.weight(.medium))
                    .lineLimit(3)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                NoteTextEditor(text: noteBinding,
                               currentQuadrant: currentQuadrant,
                               onNavigate: onNavigate,
                               onNew: onNew,
                               onShowAll: onShowAll)
                    .padding(.horizontal, 14)
            }
            .background(Color.white)
            .navigationTitle("Appunti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine", action: onClose)
                }
            }
        }
    }

    private var currentQuadrant: Int {
        store.activeMatrix.quadrants.firstIndex(where: { quadrant in
            quadrant.contains(where: { $0.id == entryID })
        }) ?? 1
    }
}

private struct NoteTextEditor: UIViewRepresentable {
    @Binding var text: String
    let currentQuadrant: Int
    let onNavigate: (Int) -> Void
    let onNew: () -> Void
    let onShowAll: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let editor = UITextView(frame: .zero)
        editor.backgroundColor = .white
        editor.textColor = .black
        editor.font = .preferredFont(forTextStyle: .body)
        editor.adjustsFontForContentSizeCategory = true
        editor.keyboardDismissMode = .interactive
        editor.autocorrectionType = .yes
        editor.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 15, right: 0)
        editor.text = text
        editor.delegate = context.coordinator
        context.coordinator.editor = editor

        let bar = MatrixKeyboardBar(currentQuadrant: currentQuadrant)
        bar.onNavigate = { [weak coordinator = context.coordinator] q in
            coordinator?.editor?.resignFirstResponder()
            coordinator?.parent.onNavigate(q)
        }
        bar.onNew = { [weak coordinator = context.coordinator] in
            coordinator?.editor?.resignFirstResponder()
            coordinator?.parent.onNew()
        }
        bar.onShowAll = { [weak coordinator = context.coordinator] in
            coordinator?.editor?.resignFirstResponder()
            coordinator?.parent.onShowAll()
        }
        bar.onChooseKind = { [weak coordinator = context.coordinator] kind in
            coordinator?.setLineMarker(kind == .bullet ? "" : kind.prefix)
            coordinator?.bar?.selectKind(kind)
        }
        bar.onIndent = { [weak coordinator = context.coordinator] amount in
            coordinator?.indent(amount)
        }
        editor.inputAccessoryView = bar
        context.coordinator.bar = bar
        return editor
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.bar?.selectQuadrant(currentQuadrant)
        if view.text != text {
            let selection = view.selectedRange
            view.text = text
            view.selectedRange = NSRange(location: min(selection.location, (text as NSString).length),
                                         length: 0)
        }
        if !context.coordinator.didFocus {
            context.coordinator.didFocus = true
            DispatchQueue.main.async { [weak view] in
                guard let view = view, view.window != nil else { return }
                view.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteTextEditor
        weak var editor: UITextView?
        weak var bar: MatrixKeyboardBar?
        var didFocus = false

        init(parent: NoteTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }

        func setLineMarker(_ prefix: String) {
            guard let editor = editor else { return }
            let source = (editor.text ?? "") as NSString
            let selection = editor.selectedRange
            let range = source.lineRange(for: NSRange(location: selection.location, length: 0))
            let line = source.substring(with: range)
            let hasNewline = line.hasSuffix("\n")
            var cleaned = hasNewline ? String(line.dropLast()) : line
            for kind in ACTEntryKind.allCases {
                if cleaned.hasPrefix(kind.prefix) {
                    cleaned = String(cleaned.dropFirst(kind.prefix.count))
                    break
                }
            }
            editor.text = source.replacingCharacters(in: range,
                         with: prefix + cleaned + (hasNewline ? "\n" : ""))
            editor.selectedRange = NSRange(location: range.location + (prefix as NSString).length
                + (cleaned as NSString).length, length: 0)
            textViewDidChange(editor)
            editor.becomeFirstResponder()
        }

        func indent(_ amount: Int) {
            guard let editor = editor else { return }
            let source = (editor.text ?? "") as NSString
            let caret = editor.selectedRange
            let range = source.lineRange(for: NSRange(location: caret.location, length: 0))
            let full = source.substring(with: range)
            let trailing = full.hasSuffix("\n") ? "\n" : ""
            var line = trailing.isEmpty ? full : String(full.dropLast())
            if amount > 0 {
                line = "    ↳ " + line
            } else if line.hasPrefix("    ↳ ") {
                line.removeFirst(6)
            } else if line.hasPrefix("    ") {
                line.removeFirst(4)
            } else { return }
            editor.text = source.replacingCharacters(in: range, with: line + trailing)
            editor.selectedRange = NSRange(location: range.location + (line as NSString).length,
                                           length: 0)
            textViewDidChange(editor)
            editor.becomeFirstResponder()
        }
    }
}
