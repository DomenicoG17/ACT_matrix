import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ACTMatrix: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    // Reading order: top-left, top-right, bottom-left, bottom-right.
    var quadrants: [[String]] = Array(repeating: [""], count: 4)

    var itemCount: Int {
        quadrants.flatMap { $0 }.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Matrice del \(createdAt.formatted(date: .abbreviated, time: .shortened))"
            : title
    }

    mutating func repairIfNeeded() {
        while quadrants.count < 4 { quadrants.append([""]) }
        if quadrants.count > 4 { quadrants = Array(quadrants.prefix(4)) }
        for index in 0..<4 where quadrants[index].isEmpty {
            quadrants[index] = [""]
        }
    }
}

struct MatrixBackup: Codable {
    var version: Int = 1
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
            matrices = repaired.sorted { $0.createdAt > $1.createdAt }
            activeID = matrices.contains(where: { $0.id == backup.activeID })
                ? backup.activeID : matrices[0].id
        } else {
            let first = ACTMatrix()
            matrices = [first]
            activeID = first.id
        }
        // Persist the timestamp of the initial, still-empty matrix as well.
        save()
    }

    var activeMatrix: ACTMatrix {
        matrices.first(where: { $0.id == activeID }) ?? matrices[0]
    }

    func lines(in quadrant: Int) -> [String] {
        guard (0..<4).contains(quadrant) else { return [""] }
        return activeMatrix.quadrants[quadrant]
    }

    func updateLines(_ lines: [String], in quadrant: Int) {
        guard (0..<4).contains(quadrant),
              let index = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        let newLines = lines.isEmpty ? [""] : lines
        guard matrices[index].quadrants[quadrant] != newLines else { return }
        matrices[index].quadrants[quadrant] = newLines
        matrices[index].updatedAt = Date()
        save()
    }

    // Visiting a quadrant always puts the cursor on an empty bullet at the end.
    // Reuse an existing empty bullet rather than accumulating blank lines.
    func prepareNewBullet(in quadrant: Int) {
        guard (0..<4).contains(quadrant),
              let index = matrices.firstIndex(where: { $0.id == activeID }) else { return }
        if matrices[index].quadrants[quadrant].last?.isEmpty == false {
            matrices[index].quadrants[quadrant].append("")
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
        guard backup.version == 1 else { throw BackupError.unsupportedVersion }
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
            // iOS data protection also applies when the phone is locked.
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
