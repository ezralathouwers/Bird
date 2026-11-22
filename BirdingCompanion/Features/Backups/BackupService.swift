import Foundation
import Combine
import CryptoKit

struct BackupPreview: Identifiable, Sendable {
    let id = UUID()
    let createdAt: Date?
    let archive: BirdingArchive
    let expectedRevision: UUID
}

enum BackupError: LocalizedError {
    case invalid, unsupported, folderRequired, ownFolder, changed, busy, activeSession, tooLarge
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Dit back-upbestand is te groot voor deze versie van Birder."
        case .invalid: "Dit bestand is geen geldige Birder-back-up of is beschadigd."
        case .unsupported: "Deze back-upversie of herstelopslag wordt nog niet ondersteund."
        case .folderRequired: "Kies eerst een back-upmap om je huidige gegevens veilig te bewaren."
        case .ownFolder: "Kies een map buiten Birder, bij voorkeur in iCloud Drive."
        case .changed: "Je gegevens zijn ondertussen gewijzigd. Open de back-up opnieuw om het herstel te controleren."
        case .busy: "Er wordt nog een back-up verwerkt. Wacht even en probeer opnieuw."
        case .activeSession: "Rond eerst je lopende vogelsessie af voordat je een back-up herstelt."
        }
    }
}

enum BackupCodec {
    struct Document: Codable {
        let format: String
        let version: Int
        let createdAt: Date
        let payload: Data
        let sha256: String
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func validate(_ archive: BirdingArchive) throws {
        guard archive.version == 2 || archive.version == 3 else { throw BackupError.unsupported }
        try ObservationStore.validateArchive(observations: archive.observations, sessions: archive.sessions)
        for log in archive.observations where !log.observedAt.timeIntervalSince1970.isFinite { throw BackupError.invalid }
        let goals = archive.goals ?? []
        guard Set(goals.map(\.id)).count == goals.count else { throw BackupError.invalid }
        for goal in goals {
            try goal.validate()
            guard goal.createdAt.timeIntervalSince1970.isFinite else { throw BackupError.invalid }
        }
    }
    static func encode(payload: Data, date: Date = Date()) throws -> Data {
        guard payload.count <= 64 * 1024 * 1024 else { throw BackupError.tooLarge }
        guard date.timeIntervalSince1970.isFinite else { throw BackupError.invalid }
        let archive = try JSONDecoder().decode(BirdingArchive.self, from: payload)
        try validate(archive)
        let document = Document(format: "BirderBackup", version: 1, createdAt: date, payload: payload, sha256: digest(payload))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }
    static func decode(_ data: Data) throws -> (archive: BirdingArchive, date: Date?) {
        guard !data.isEmpty else { throw BackupError.invalid }
        guard data.count <= 128 * 1024 * 1024 else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        if let document = try? decoder.decode(Document.self, from: data) {
            guard document.format == "BirderBackup", document.version == 1,
                  document.createdAt.timeIntervalSince1970.isFinite,
                  digest(document.payload) == document.sha256 else { throw BackupError.invalid }
            let archive = try decoder.decode(BirdingArchive.self, from: document.payload)
            try validate(archive); return (archive, document.createdAt)
        }
        // Accept earlier full-archive exports and legacy observation-only exports.
        let archive: BirdingArchive
        if let full = try? decoder.decode(BirdingArchive.self, from: data) { archive = full }
        else if let logs = try? decoder.decode([Observation].self, from: data) {
            archive = BirdingArchive(observations: logs, sessions: [], goals: [])
        } else { throw BackupError.invalid }
        try validate(archive); return (archive, nil)
    }
}

// NSFileCoordinator may invoke its accessors on a provider's queue. Capture a
// lock-protected result instead of mutable local variables across that boundary.
private final class BackupIOResult<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?
    func set(_ value: Result<Value, Error>) { lock.lock(); result = value; lock.unlock() }
    func get() throws -> Value {
        lock.lock(); let current = result; lock.unlock()
        guard let current else { throw BackupError.invalid }
        return try current.get()
    }
}

actor BackupFiles {
    func write(payload: Data, bookmark: Data, reason: String) throws -> URL {
        var stale = false
        let root = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale else { throw BackupError.folderRequired }
        let access = root.startAccessingSecurityScopedResource()
        defer { if access { root.stopAccessingSecurityScopedResource() } }
        return try write(payload: payload, directory: root, reason: reason)
    }
    func write(payload: Data, directory: URL, reason: String) throws -> URL {
        let bytes = try BackupCodec.encode(payload: payload)
        let folder = directory.appendingPathComponent("Birder-reservekopieen", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let file = folder.appendingPathComponent("Birder-\(stamp)-\(reason)-\(UUID().uuidString).json")
        var coordinationError: NSError?
        let outcome = BackupIOResult<Void>()
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: file, options: [], error: &coordinationError) { destination in
            outcome.set(Result {
                try bytes.write(to: destination, options: .atomic)
                let verified = try Data(contentsOf: destination)
                guard verified == bytes else { throw BackupError.invalid }
                _ = try BackupCodec.decode(verified)
            })
        }
        if let error = coordinationError { throw error }
        try outcome.get()
        return file
    }
    func exists(bookmark: Data, filename: String) throws -> Bool {
        guard filename == URL(fileURLWithPath: filename).lastPathComponent else { return false }
        var stale = false
        let root = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale else { throw BackupError.folderRequired }
        let access = root.startAccessingSecurityScopedResource()
        defer { if access { root.stopAccessingSecurityScopedResource() } }
        return FileManager.default.fileExists(atPath: root.appendingPathComponent("Birder-reservekopieen")
            .appendingPathComponent(filename).path)
    }
    func read(_ file: URL) throws -> (BirdingArchive, Date?) {
        let access = file.startAccessingSecurityScopedResource()
        defer { if access { file.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        let outcome = BackupIOResult<(BirdingArchive, Date?)>()
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: file, options: [], error: &coordinationError) { source in
            outcome.set(Result {
                let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 128 * 1024 * 1024 else { throw BackupError.tooLarge }
                let decoded = try BackupCodec.decode(Data(contentsOf: source))
                return (decoded.archive, decoded.date)
            })
        }
        if let coordinationError { throw coordinationError }
        return try outcome.get()
    }
}

@MainActor
final class BackupController: ObservableObject {
    @Published private(set) var automatic: Bool
    @Published private(set) var folderName: String?
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var lastFilename: String?
    @Published private(set) var message: String?
    @Published private(set) var isBusy = false
    private let defaults: UserDefaults
    private let files: BackupFiles
    private var pending: Task<Void, Never>?
    private var bookmark: Data?
    private var lastDigest: String?
    var hasFolder: Bool { bookmark != nil }
    init(defaults: UserDefaults = .standard, files: BackupFiles = BackupFiles()) {
        self.defaults = defaults; self.files = files
        bookmark = defaults.data(forKey: "backup.folder")
        folderName = defaults.string(forKey: "backup.folderName")
        automatic = defaults.bool(forKey: "backup.automatic")
        let time = defaults.double(forKey: "backup.lastSuccess")
        lastSuccess = time > 0 ? Date(timeIntervalSince1970: time) : nil
        lastFilename = defaults.string(forKey: "backup.lastFilename")
        lastDigest = defaults.string(forKey: "backup.lastDigest")
    }
    func configure(folder: URL, store: ObservationStore) async {
        guard !isBusy else { message = BackupError.busy.localizedDescription; return }
        pending?.cancel(); isBusy = true; message = nil
        defer { isBusy = false }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        do {
            let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().standardizedFileURL.path + "/"
            guard !folder.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(home) else { throw BackupError.ownFolder }
            let candidate = try folder.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            let payload = try store.exportArchiveData()
            let revision = store.revision
            let file = try await files.write(payload: payload, bookmark: candidate, reason: "start")
            bookmark = candidate; folderName = folder.lastPathComponent; automatic = true
            defaults.set(candidate, forKey: "backup.folder"); defaults.set(folderName, forKey: "backup.folderName")
            defaults.set(true, forKey: "backup.automatic")
            recordSuccess(file, payload: payload)
            if store.revision != revision { Task { self.schedule(store: store) } }
        } catch { message = error.localizedDescription }
    }
    func setAutomatic(_ enabled: Bool, store: ObservationStore) {
        automatic = enabled; defaults.set(enabled, forKey: "backup.automatic")
        if enabled { schedule(store: store) } else { pending?.cancel() }
    }
    func schedule(store: ObservationStore) {
        guard automatic, hasFolder, store.loadError == nil else { return }
        pending?.cancel()
        pending = Task { [weak self, weak store] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, let store, !Task.isCancelled else { return }
            await self.save(store: store, force: false)
        }
    }
    func save(store: ObservationStore, force: Bool = true) async {
        guard !isBusy else { return }
        guard let bookmark else { message = BackupError.folderRequired.localizedDescription; return }
        isBusy = true; message = nil
        let revision = store.revision
        defer {
            isBusy = false
            if store.revision != revision { schedule(store: store) }
        }
        do {
            let payload = try store.exportArchiveData()
            if !force, BackupCodec.digest(payload) == lastDigest, let lastFilename,
               try await files.exists(bookmark: bookmark, filename: lastFilename) { return }
            let file = try await files.write(payload: payload, bookmark: bookmark, reason: "backup")
            recordSuccess(file, payload: payload)
        } catch { message = error.localizedDescription }
    }
    func preview(file: URL, store: ObservationStore) async throws -> BackupPreview {
        guard !isBusy else { throw BackupError.busy }
        isBusy = true; defer { isBusy = false; schedule(store: store) }
        let revision = store.revision
        let (archive, date) = try await files.read(file)
        return BackupPreview(createdAt: date, archive: archive, expectedRevision: revision)
    }
    func restore(_ preview: BackupPreview, store: ObservationStore) async throws {
        guard !isBusy else { throw BackupError.busy }
        guard store.revision == preview.expectedRevision else { throw BackupError.changed }
        guard store.activeSession == nil else { throw BackupError.activeSession }
        isBusy = true; message = nil
        defer { isBusy = false; schedule(store: store) }
        let hasData = !store.observations.isEmpty || !store.sessions.isEmpty || !store.goals.isEmpty
        if hasData, store.loadError == nil {
            guard let bookmark else { throw BackupError.folderRequired }
            let payload = try store.exportArchiveData()
            let file = try await files.write(payload: payload, bookmark: bookmark, reason: "voor-herstel")
            recordSuccess(file, payload: payload)
        }
        try store.restoreArchive(preview.archive, expectedRevision: preview.expectedRevision)
    }
    private func recordSuccess(_ file: URL, payload: Data) {
        lastSuccess = Date(); lastFilename = file.lastPathComponent; lastDigest = BackupCodec.digest(payload)
        defaults.set(lastSuccess?.timeIntervalSince1970, forKey: "backup.lastSuccess")
        defaults.set(lastFilename, forKey: "backup.lastFilename"); defaults.set(lastDigest, forKey: "backup.lastDigest")
    }
}
