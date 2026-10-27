import Foundation
import SwiftUI
import UniformTypeIdentifiers

// The icon is a property of EACH entry, not of the whole quadrant.
// "bullet" preserves the look of notes created in ACT Matrix 1.0.
enum ACTEntryKind: String, Codable, CaseIterable {
    case bullet, thought, feeling, image, todo

    var symbol: String {
        switch self {
        case .bullet: return "•"
        case .thought: return "💭"
        case .feeling: return "🎇"
        case .image: return "🏞️"
        case .todo: return "🔲"
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

struct ACTEntry: Codable, Equatable {
    var text: String = ""
    var kind: ACTEntryKind = .bullet
}

struct ACTMatrix: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    // Reading order: top-left, top-right, bottom-left, bottom-right.
    var quadrants: [[ACTEntry]] = (0..<4).map { _ in [ACTEntry()] }

    init() {}

    // Seamlessly open BOTH the v1 [[String]] format and the new v2 [[ACTEntry]] format.
    // The same decoder is used for on-device data and imported JSON backups.
    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, updatedAt, quadrants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
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
    }
}

struct MatrixBackup: Codable {
    var version: Int = 2
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

    // Navigation goes to an empty last entry; its icon follows the previous entry.
    func prepareNewBullet(in quadrant: Int) {
        guard (0..<4).contains(quadrant),
              let index = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        let last = matrices[index].quadrants[quadrant].last ?? ACTEntry()
        if !last.text.isEmpty {
            matrices[index].quadrants[quadrant].append(ACTEntry(kind: last.kind))
            matrices[index].updatedAt = Date()
            save()
        }
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
        guard (1...2).contains(backup.version) else { throw BackupError.unsupportedVersion }
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
