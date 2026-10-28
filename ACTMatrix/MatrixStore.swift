import Foundation
import SwiftUI
import UniformTypeIdentifiers

// The icon is a property of EACH entry, not of the whole quadrant.
// "bullet" preserves the look of notes created in ACT Matrix 1.0.
enum ACTEntryKind: String, Codable, CaseIterable {
    case bullet, thought, feeling, image, todo, memory, sound

    var symbol: String {
        switch self {
        case .bullet: return "•"
        case .thought: return "💭"
        case .feeling: return "🎇"
        case .image: return "🏞️"
        case .todo: return "🔲"
        case .memory: return "🎗️"
        case .sound: return "🔈"
        }
    }

    var prefix: String { symbol + " " }

    var accessibilityName: String {
        switch self {
        case .bullet: return "Punto elenco"
        case .thought: return "Pensiero"
        case .feeling: return "Sensazione"
        case .image: return "Immagine"
        case .todo: return "Da fare"
        case .memory: return "Ricordo"
        case .sound: return "Suono"
        }
    }

    static func parse(_ line: String, fallback: ACTEntryKind = .bullet) -> ACTEntry {
        for kind in Self.allCases where line.hasPrefix(kind.prefix) {
            return ACTEntry(text: String(line.dropFirst(kind.prefix.count)), kind: kind)
        }
        // Some old/hand-edited bullets may lack a following space.
        if line.hasPrefix("•") {
            return ACTEntry(text: String(line.dropFirst()).trimmingCharacters(in: .whitespaces), kind: .bullet)
        }
        return ACTEntry(text: line, kind: fallback)
    }
}

struct ACTEntry: Identifiable, Codable, Equatable {
    // Persistent IDs let counters, notes and custom ordering survive text edits.
    var id: UUID = UUID()
    var text: String = ""
    var kind: ACTEntryKind = .bullet
    var recurrenceCount: Int = 0
    var indentLevel: Int = 0
    var note: String = ""

    init(id: UUID = UUID(), text: String = "", kind: ACTEntryKind = .bullet,
         recurrenceCount: Int = 0, indentLevel: Int = 0, note: String = "") {
        self.id = id
        self.text = text
        self.kind = kind
        self.recurrenceCount = max(0, recurrenceCount)
        self.indentLevel = max(0, min(4, indentLevel))
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, kind, recurrenceCount, indentLevel, note
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try values.decodeIfPresent(String.self, forKey: .text) ?? ""
        kind = try values.decodeIfPresent(ACTEntryKind.self, forKey: .kind) ?? .bullet
        recurrenceCount = max(0, try values.decodeIfPresent(Int.self, forKey: .recurrenceCount) ?? 0)
        indentLevel = max(0, min(4, try values.decodeIfPresent(Int.self, forKey: .indentLevel) ?? 0))
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    var displayPrefix: String {
        let indent = String(repeating: "    ", count: indentLevel)
        // Nested entries retain BOTH their branching arrow and selected type.
        return indent + (indentLevel > 0 ? "↳ " + kind.prefix : kind.prefix)
    }

    // Quotation marks are a presentation preference, not part of stored text.
    func bodyText(quoteThoughts: Bool) -> String {
        guard kind == .thought && quoteThoughts else { return text }
        // Avoid double quotation marks in older entries typed manually with quotes.
        let body = text.hasPrefix("“") && text.hasSuffix("”") && text.count >= 2
            ? String(text.dropFirst().dropLast()) : text
        return "“\(body)”"
    }

    func formattedLine(quoteThoughts: Bool) -> String {
        displayPrefix + bodyText(quoteThoughts: quoteThoughts)
    }

    var displayLine: String { displayPrefix + text }

    // Parse both native icons and the L-shaped nested marker.
    // For a nested item its original type (e.g. to-do) is retained in its model.
    static func parseLine(_ line: String, fallback: ACTEntry? = nil) -> ACTEntry {
        var text = line
        var level = 0
        while text.hasPrefix("    ") && level < 4 {
            text.removeFirst(4)
            level += 1
        }
        if text.hasPrefix("↳ ") {
            text.removeFirst(2)
            // Old nested lines only had ↳; new ones also include 💭/🎇/🏞️/🔲.
            let nested = ACTEntryKind.parse(text, fallback: fallback?.kind ?? .bullet)
            return ACTEntry(text: nested.text, kind: nested.kind, indentLevel: max(1, level))
        }
        let parsed = ACTEntryKind.parse(text, fallback: fallback?.kind ?? .bullet)
        return ACTEntry(text: parsed.text, kind: parsed.kind, indentLevel: level)
    }
}

struct ACTMatrix: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    // Reading order: top-left, top-right, bottom-left, bottom-right.
    var quadrants: [[ACTEntry]] = (0..<4).map { _ in [ACTEntry()] }
    // Custom order applies only to the to-do screen, never the original matrix.
    var todoOrder: [UUID] = []
    // Per-matrix counter for moments of observing one's experience.
    var meNoticingCount: Int = 0

    init() {}

    // Seamlessly open BOTH the v1 [[String]] format and the new v2 [[ACTEntry]] format.
    // The same decoder is used for on-device data and imported JSON backups.
    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, updatedAt, quadrants, todoOrder, meNoticingCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        todoOrder = try container.decodeIfPresent([UUID].self, forKey: .todoOrder) ?? []
        meNoticingCount = max(0, try container.decodeIfPresent(Int.self, forKey: .meNoticingCount) ?? 0)
        if let current = try? container.decode([[ACTEntry]].self, forKey: .quadrants) {
            quadrants = current
        } else if let legacy = try? container.decode([[String]].self, forKey: .quadrants) {
            quadrants = legacy.map { $0.map { ACTEntry(text: $0, kind: .bullet) } }
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .quadrants, in: container, debugDescription: "Unsupported quadrant data"
            )
        }
        repairIfNeeded()
    }

    var itemCount: Int {
        quadrants.flatMap { $0 }.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Matrice del \(createdAt.formatted(date: .abbreviated, time: .shortened))"
            : title
    }

    mutating func repairIfNeeded() {
        while quadrants.count < 4 { quadrants.append([ACTEntry()]) }
        if quadrants.count > 4 { quadrants = Array(quadrants.prefix(4)) }
        for index in 0..<4 where quadrants[index].isEmpty {
            quadrants[index] = [ACTEntry()]
        }
        // Prevent a rare duplicate ID in an imported or manually edited backup.
        var seen = Set<UUID>()
        for q in quadrants.indices {
            for i in quadrants[q].indices {
                if !seen.insert(quadrants[q][i].id).inserted {
                    quadrants[q][i].id = UUID()
                }
            }
        }
    }
}

struct MatrixBackup: Codable {
    var version: Int = 6
    var matrices: [ACTMatrix]
    var activeID: UUID
}

@MainActor
final class MatrixStore: ObservableObject {
    @Published private(set) var matrices: [ACTMatrix]
    @Published private(set) var activeID: UUID
    @Published var saveError: String?

    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("ACTMatrix", isDirectory: true)
        fileURL = directory.appendingPathComponent("matrices.json")

        if let data = try? Data(contentsOf: fileURL),
           let backup = try? Self.decoder.decode(MatrixBackup.self, from: data),
           !backup.matrices.isEmpty {
            var repaired = backup.matrices
            for index in repaired.indices { repaired[index].repairIfNeeded() }
            // Finish computing the restored data before accessing stored properties.
            // In Swift, referring to self.matrices before activeID has been set
            // is not permitted inside an initializer.
            let sortedMatrices = repaired.sorted { $0.createdAt > $1.createdAt }
            let restoredActiveID = sortedMatrices.contains { $0.id == backup.activeID }
                ? backup.activeID : sortedMatrices[0].id
            matrices = sortedMatrices
            activeID = restoredActiveID
        } else {
            let first = ACTMatrix()
            matrices = [first]
            activeID = first.id
        }
        save()
    }

    var activeMatrix: ACTMatrix {
        matrices.first(where: { $0.id == activeID }) ?? matrices[0]
    }

    func entries(in quadrant: Int) -> [ACTEntry] {
        guard (0..<4).contains(quadrant) else { return [ACTEntry()] }
        return activeMatrix.quadrants[quadrant]
    }

    func updateEntries(_ entries: [ACTEntry], in quadrant: Int) {
        guard (0..<4).contains(quadrant),
              let index = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        let value = entries.isEmpty ? [ACTEntry()] : entries
        guard matrices[index].quadrants[quadrant] != value else { return }
        matrices[index].quadrants[quadrant] = value
        matrices[index].updatedAt = Date()
        save()
    }

    // Count a recurring thought/feeling/image/action without affecting its text,
    // selected icon or any other item. Also works from the 2x2 overview.
    func adjustRecurrence(in quadrant: Int, at entryIndex: Int, by delta: Int) {
        guard (0..<4).contains(quadrant),
              let matrixIndex = matrices.firstIndex(where: { $0.id == activeID }),
              matrices[matrixIndex].quadrants[quadrant].indices.contains(entryIndex)
        else { return }
        let old = matrices[matrixIndex].quadrants[quadrant][entryIndex].recurrenceCount
        let newValue: Int
        if delta > 0 {
            newValue = old == Int.max ? old : old + 1
        } else if delta < 0 {
            newValue = max(0, old - 1)
        } else { return }
        guard newValue != old else { return }
        matrices[matrixIndex].quadrants[quadrant][entryIndex].recurrenceCount = newValue
        matrices[matrixIndex].updatedAt = Date()
        save()
    }

    // Navigation goes to an empty last entry; its icon follows the previous entry.
    func prepareNewBullet(in quadrant: Int) {
        guard (0..<4).contains(quadrant),
              let index = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        let last = matrices[index].quadrants[quadrant].last ?? ACTEntry()
        if !last.text.isEmpty {
            matrices[index].quadrants[quadrant].append(
                ACTEntry(kind: last.kind, indentLevel: 0)
            )
            matrices[index].updatedAt = Date()
            save()
        } else if last.indentLevel != 0 {
            // Returning from overview always starts a fresh top-level entry.
            let lastIndex = matrices[index].quadrants[quadrant].count - 1
            matrices[index].quadrants[quadrant][lastIndex].indentLevel = 0
            save()
        }
    }

    func updateNote(_ text: String, for entryID: UUID, in matrixID: UUID? = nil) {
        guard let matrixIndex = matrices.firstIndex(where: { $0.id == (matrixID ?? activeID) }) else { return }
        for quadrant in 0..<4 {
            if let index = matrices[matrixIndex].quadrants[quadrant].firstIndex(where: { $0.id == entryID }) {
                guard matrices[matrixIndex].quadrants[quadrant][index].note != text else { return }
                matrices[matrixIndex].quadrants[quadrant][index].note = text
                matrices[matrixIndex].updatedAt = Date()
                save()
                return
            }
        }
    }

    func entry(withID id: UUID, in matrixID: UUID? = nil) -> ACTEntry? {
        (matrices.first(where: { $0.id == (matrixID ?? activeID) }) ?? activeMatrix)
            .quadrants.flatMap { $0 }.first { $0.id == id }
    }

    struct TodoAcrossMatrices: Identifiable {
        let matrixID: UUID
        let matrixTitle: String
        let date: Date
        let entry: ACTEntry
        var id: UUID { entry.id }
    }

    func allTodosAcrossMatrices() -> [TodoAcrossMatrices] {
        matrices.flatMap { matrix in
            matrix.quadrants.flatMap { $0 }
                .filter { $0.kind == .todo && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { TodoAcrossMatrices(matrixID: matrix.id,
                                          matrixTitle: matrix.displayTitle,
                                          date: matrix.createdAt, entry: $0) }
        }
    }

    func setTodoOrder(_ ids: [UUID]) {
        guard let matrixIndex = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        let currentIDs = Set(allTodos().map(\.id))
        guard Set(ids) == currentIDs, ids.count == currentIDs.count else { return }
        matrices[matrixIndex].todoOrder = ids
        matrices[matrixIndex].updatedAt = Date()
        save()
    }

    func allTodos() -> [ACTEntry] {
        let items = activeMatrix.quadrants.flatMap { $0 }.filter {
            $0.kind == .todo && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let order = activeMatrix.todoOrder
        return items.sorted { left, right in
            let l = order.firstIndex(of: left.id) ?? Int.max
            let r = order.firstIndex(of: right.id) ?? Int.max
            if l != r { return l < r }
            let li = items.firstIndex(where: { $0.id == left.id }) ?? 0
            let ri = items.firstIndex(where: { $0.id == right.id }) ?? 0
            return li < ri
        }
    }

    // Dragging in the to-do list changes ONLY todoOrder, not quadrants.
    func moveTodo(sourceID: UUID, to targetID: UUID, after: Bool) {
        guard sourceID != targetID,
              let matrixIndex = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        var ids = allTodos().map(\.id)
        guard let source = ids.firstIndex(of: sourceID),
              ids.contains(targetID) else { return }
        ids.remove(at: source)
        guard let destination = ids.firstIndex(of: targetID) else { return }
        ids.insert(sourceID, at: destination + (after ? 1 : 0))
        matrices[matrixIndex].todoOrder = ids
        matrices[matrixIndex].updatedAt = Date()
        save()
    }

    // Dragging a matrix row reorders entries only INSIDE its original quadrant.
    func moveEntry(in quadrant: Int, sourceID: UUID, to targetID: UUID, after: Bool) {
        guard (0..<4).contains(quadrant), sourceID != targetID,
              let matrixIndex = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        var items = matrices[matrixIndex].quadrants[quadrant]
        guard let from = items.firstIndex(where: { $0.id == sourceID }) else { return }
        let item = items.remove(at: from)
        guard let to = items.firstIndex(where: { $0.id == targetID }) else { return }
        items.insert(item, at: to + (after ? 1 : 0))
        matrices[matrixIndex].quadrants[quadrant] = items
        matrices[matrixIndex].updatedAt = Date()
        save()
    }

    func adjustMeNoticing(by delta: Int) {
        guard let index = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        let old = matrices[index].meNoticingCount
        let next: Int
        if delta > 0 { next = old < Int.max ? old + 1 : old }
        else if delta < 0 { next = max(0, old - 1) }
        else { return }
        guard next != old else { return }
        matrices[index].meNoticingCount = next
        matrices[index].updatedAt = Date()
        save()
    }

    // Matrices are ordered by creation date (newest first): swipe up for older,
    // swipe down for newer. Do not wrap at either end.
    @discardableResult
    func navigateMatrix(by offset: Int) -> Bool {
        guard let current = matrices.firstIndex(where: { $0.id == activeID }),
              matrices.indices.contains(current + offset) else { return false }
        activeID = matrices[current + offset].id
        save()
        return true
    }

    func createMatrix() {
        let matrix = ACTMatrix()
        matrices.insert(matrix, at: 0)
        activeID = matrix.id
        save()
    }

    func activate(_ id: UUID) {
        guard matrices.contains(where: { $0.id == id }) else { return }
        activeID = id
        save()
    }

    func rename(_ id: UUID, title: String) {
        guard let index = matrices.firstIndex(where: { $0.id == id }) else { return }
        matrices[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        matrices[index].updatedAt = Date()
        save()
    }

    func delete(_ id: UUID) {
        matrices.removeAll { $0.id == id }
        if matrices.isEmpty { matrices = [ACTMatrix()] }
        if !matrices.contains(where: { $0.id == activeID }) {
            activeID = matrices[0].id
        }
        save()
    }

    func backupData() throws -> Data {
        try Self.encoder.encode(MatrixBackup(matrices: matrices, activeID: activeID))
    }

    // Import is non-destructive: new IDs are merged, existing IDs kept.
    @discardableResult
    func importBackup(_ data: Data) throws -> Int {
        let backup = try Self.decoder.decode(MatrixBackup.self, from: data)
        guard (1...6).contains(backup.version) else { throw BackupError.unsupportedVersion }
        let existingIDs = Set(matrices.map(\.id))
        var incoming = backup.matrices.filter { !existingIDs.contains($0.id) }
        for index in incoming.indices { incoming[index].repairIfNeeded() }
        matrices.append(contentsOf: incoming)
        matrices.sort { $0.createdAt > $1.createdAt }
        save()
        return incoming.count
    }

    private func save() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true
            )
            let data = try backupData()
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            saveError = nil
        } catch {
            saveError = "Impossibile salvare le matrici: \(error.localizedDescription)"
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    enum BackupError: LocalizedError {
        case unsupportedVersion

        var errorDescription: String? {
            "Questa versione del backup non è supportata."
        }
    }
}

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    static let writableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
