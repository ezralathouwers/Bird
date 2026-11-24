import Foundation
import Combine

protocol ObservationPersistence {
    func load() throws -> [Observation]
    func preserveBeforeRestore() throws
    func save(_ observations: [Observation]) throws
    func loadSessions() throws -> [BirdSession]
    func loadGoals() throws -> [BirdGoal]
    func save(_ observations: [Observation], sessions: [BirdSession], goals: [BirdGoal]) throws
    func save(_ observations: [Observation], sessions: [BirdSession]) throws
}

extension ObservationPersistence {
    func preserveBeforeRestore() throws { throw BackupError.unsupported }
    func loadGoals() throws -> [BirdGoal] { [] }
    func save(_ observations: [Observation], sessions: [BirdSession], goals: [BirdGoal]) throws {
        guard goals.isEmpty else { throw GoalError.unsupportedPersistence }
        try save(observations, sessions: sessions)
    }
    func loadSessions() throws -> [BirdSession] { [] }
    func save(_ observations: [Observation], sessions: [BirdSession]) throws {
        guard sessions.isEmpty else { throw SessionError.unsupportedPersistence }
        try save(observations)
    }
}

struct JSONObservationPersistence: ObservationPersistence {
    let url: URL
    private func archive() throws -> BirdingArchive {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return BirdingArchive(observations: [], sessions: [])
        }
        let data = try Data(contentsOf: url)
        // Read the previous observation-array format without rewriting it on load.
        if let legacy = try? JSONDecoder().decode([Observation].self, from: data) {
            return BirdingArchive(observations: legacy, sessions: [])
        }
        let result = try JSONDecoder().decode(BirdingArchive.self, from: data)
        guard result.version == 2 || result.version == 3 else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }
    func preserveBeforeRestore() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let directory = url.deletingLastPathComponent().appendingPathComponent("RecoveryCopies", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent("before-restore-\(UUID().uuidString).json"))
    }
    func load() throws -> [Observation] { try archive().observations }
    func loadSessions() throws -> [BirdSession] { try archive().sessions }
    func loadGoals() throws -> [BirdGoal] { try archive().goals ?? [] }
    func save(_ observations: [Observation]) throws {
        try save(observations, sessions: archive().sessions)
    }
    func save(_ observations: [Observation], sessions: [BirdSession]) throws {
        try save(observations, sessions: sessions, goals: archive().goals ?? [])
    }
    func save(_ observations: [Observation], sessions: [BirdSession], goals: [BirdGoal]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // One atomic write: never publish a session without its individual observations.
        try JSONEncoder().encode(BirdingArchive(observations: observations, sessions: sessions, goals: goals))
            .write(to: url, options: .atomic)
    }
}

enum SpeciesLogStatus {
    case logged, notLogged, unavailable
}

@MainActor
final class ObservationStore: ObservableObject {
    @Published private(set) var observations: [Observation] = []
    @Published private(set) var goals: [BirdGoal] = []
    @Published private(set) var sessions: [BirdSession] = []
    @Published private(set) var loadError: String?
    @Published private(set) var revision = UUID()
    private let persistence: any ObservationPersistence

    init(persistence: any ObservationPersistence) {
        self.persistence = persistence
        do {
            let loaded = try persistence.load()
            for observation in loaded { try observation.validate() }
            guard Set(loaded.map(\.id)).count == loaded.count else { throw ObservationError.duplicateID }
            let loadedSessions = try persistence.loadSessions()
            try Self.validateArchive(observations: loaded, sessions: loadedSessions)
            let loadedGoals = try persistence.loadGoals()
            for goal in loadedGoals { try goal.validate() }
            guard Set(loadedGoals.map(\.id)).count == loadedGoals.count else { throw GoalError.duplicateID }
            observations = loaded
            sessions = loadedSessions
            goals = loadedGoals
        } catch {
            loadError = "Waarnemingen konden niet worden geladen. Het bestand blijft bewaard. \(error.localizedDescription)"
        }
    }

    func save(_ observation: Observation, editing: Bool = false) throws {
        guard loadError == nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try observation.validate()
        var updated = observations
        if editing {
            guard let index = updated.firstIndex(where: { $0.id == observation.id }) else {
                throw ObservationError.missingRecord
            }
            updated[index] = observation
        } else {
            guard !updated.contains(where: { $0.id == observation.id }) else { throw ObservationError.duplicateID }
            updated.append(observation)
        }
        try Self.validateArchive(observations: updated, sessions: sessions)
        try persistence.save(updated, sessions: sessions, goals: goals)
        observations = updated
        revision = UUID()
    }

    var activeSession: BirdSession? { sessions.first { $0.isLive && $0.endedAt == nil } }

    var completedSessions: [BirdSession] {
        sessions.filter { $0.endedAt != nil }.sorted {
            $0.startedAt == $1.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.startedAt > $1.startedAt
        }
    }

    func observations(in session: BirdSession) -> [Observation] {
        observations.filter { $0.sessionID == session.id }.sorted { $0.observedAt > $1.observedAt }
    }

    func startSession(_ session: BirdSession) throws {
        guard activeSession == nil else { throw SessionError.alreadyActive }
        guard session.isLive, session.endedAt == nil else { throw SessionError.invalidSession }
        try commit(observations: observations, sessions: sessions + [session])
    }

    func addCompletedSession(_ session: BirdSession, species: [Species]) throws {
        guard !session.isLive, session.endedAt != nil else { throw SessionError.invalidSession }
        var seen = Set<String>()
        let logs = species.filter { seen.insert($0.id).inserted }.map { bird in
            var log = Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion,
                observedAt: session.startedAt, locationName: session.locationName, count: 1, notes: "", status: .confirmed)
            log.latitude = session.latitude; log.longitude = session.longitude
            log.countryCode = session.countryCode; log.sessionID = session.id
            log.source = "session-retrospective"
            return log
        }
        try commit(observations: observations + logs, sessions: sessions + [session])
    }

    func logLive(_ species: Species, sessionID: UUID, at date: Date, location: SessionLogLocation) throws {
        guard let session = activeSession, session.id == sessionID else { throw SessionError.noActiveSession }
        guard !observations.contains(where: { $0.sessionID == sessionID && $0.speciesID == species.id }) else { throw SessionError.duplicateSpecies }
        var log = Observation(speciesID: species.id, taxonomyVersion: species.taxonomyVersion,
            observedAt: date, locationName: location.name, count: 1, notes: "", status: .confirmed)
        log.latitude = location.latitude; log.longitude = location.longitude
        log.countryCode = location.countryCode; log.sessionID = session.id; log.source = "session-live"
        try commit(observations: observations + [log], sessions: sessions)
    }

    func finishSession(at date: Date = Date()) throws {
        guard let active = activeSession, let index = sessions.firstIndex(where: { $0.id == active.id }) else {
            throw SessionError.noActiveSession
        }
        var updated = sessions
        updated[index].endedAt = date
        try commit(observations: observations, sessions: updated)
    }

    func removeLiveObservation(id: UUID, sessionID: UUID) throws {
        guard activeSession?.id == sessionID else { throw SessionError.noActiveSession }
        guard observations.contains(where: { $0.id == id && $0.sessionID == sessionID }) else { throw ObservationError.missingRecord }
        try commit(observations: observations.filter { $0.id != id }, sessions: sessions)
    }

    // A review can replace only its own session and only the snapshot it opened.
    func completeSession(_ review: BirdSession, logs: [Observation], expectedLogs: [Observation]) throws {
        guard activeSession?.id == review.id, review.isLive else { throw SessionError.noActiveSession }
        try replaceReviewedSession(review, logs: logs, expectedLogs: expectedLogs)
    }
    func updateCompletedSession(_ review: BirdSession, logs: [Observation], expectedLogs: [Observation]) throws {
        guard sessions.contains(where: { $0.id == review.id && $0.endedAt != nil }) else { throw SessionError.invalidSession }
        try replaceReviewedSession(review, logs: logs, expectedLogs: expectedLogs)
    }
    private func replaceReviewedSession(_ review: BirdSession, logs: [Observation], expectedLogs: [Observation]) throws {
        guard let index = sessions.firstIndex(where: { $0.id == review.id }), review.endedAt != nil,
              review.isLive == sessions[index].isLive,
              logs.allSatisfy({ $0.sessionID == review.id }) else { throw SessionError.invalidSession }
        let current = observations.filter { $0.sessionID == review.id }
        guard current.count == expectedLogs.count, current.allSatisfy({ expectedLogs.contains($0) }) else { throw SessionError.reviewChanged }
        let oldCounts = Dictionary(grouping: current, by: \.speciesID).mapValues(\.count)
        let newCounts = Dictionary(grouping: logs, by: \.speciesID).mapValues(\.count)
        guard newCounts.allSatisfy({ $0.value <= max(1, oldCounts[$0.key] ?? 0) }) else { throw SessionError.duplicateSpecies }
        var updated = sessions; updated[index] = review
        try commit(observations: observations.filter { $0.sessionID != review.id } + logs, sessions: updated)
    }

    private func commit(observations: [Observation], sessions: [BirdSession]) throws {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try Self.validateArchive(observations: observations, sessions: sessions)
        try persistence.save(observations, sessions: sessions, goals: goals)
        self.observations = observations
        self.sessions = sessions
        revision = UUID()
    }

    nonisolated static func validateArchive(observations: [Observation], sessions: [BirdSession]) throws {
        for session in sessions { try session.validate() }
        guard Set(sessions.map(\.id)).count == sessions.count,
              Set(observations.map(\.id)).count == observations.count,
              sessions.filter({ $0.endedAt == nil }).count <= 1 else { throw SessionError.invalidSession }
        let byID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        for log in observations {
            try log.validate()
            if let id = log.sessionID {
                guard let session = byID[id], log.latitude != nil, log.longitude != nil,
                      !log.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      log.observedAt >= session.startedAt,
                      session.endedAt.map({ log.observedAt <= $0 }) ?? true else { throw SessionError.invalidLog }
            }
        }
    }

    @discardableResult
    func importBirda(_ batch: BirdaImportBatch, expectedRevision: UUID) throws -> BirdaImportPlan {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        guard revision == expectedRevision else {
            throw BirdaImportError(message: "Je gegevens zijn ondertussen gewijzigd. Open de CSV opnieuw om de import te controleren.")
        }
        guard activeSession == nil else { throw SessionError.alreadyActive }
        let plan = try BirdaImport.plan(batch, observations: observations, sessions: sessions)
        guard plan.addedObservations > 0 || plan.addedSessions > 0 else { return plan }
        try persistence.preserveBeforeRestore()
        try persistence.save(plan.observations, sessions: plan.sessions, goals: goals)
        observations = plan.observations; sessions = plan.sessions; revision = UUID()
        return plan
    }

    func restoreArchive(_ archive: BirdingArchive, expectedRevision: UUID) throws {
        guard revision == expectedRevision else { throw BackupError.changed }
        guard activeSession == nil else { throw BackupError.activeSession }
        try BackupCodec.validate(archive)
        // Preserve even an unreadable source file before replacing it.
        try persistence.preserveBeforeRestore()
        try persistence.save(archive.observations, sessions: archive.sessions, goals: archive.goals ?? [])
        observations = archive.observations; sessions = archive.sessions; goals = archive.goals ?? []
        loadError = nil; revision = UUID()
    }

    func exportArchiveData() throws -> Data {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(BirdingArchive(observations: observations, sessions: sessions, goals: goals))
    }

    func addGoal(_ goal: BirdGoal) throws {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try goal.validate()
        guard !goals.contains(where: { $0.id == goal.id }) else { throw GoalError.duplicateID }
        let updated = goals + [goal]
        try persistence.save(observations, sessions: sessions, goals: updated)
        goals = updated
        revision = UUID()
    }

    func updateGoal(_ goal: BirdGoal) throws {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try goal.validate()
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { throw GoalError.missingGoal }
        var updated = goals
        var edited = goal
        edited.createdAt = goals[index].createdAt
        updated[index] = edited
        try persistence.save(observations, sessions: sessions, goals: updated)
        goals = updated
        revision = UUID()
    }

    func logStatus(for speciesID: String) -> SpeciesLogStatus {
        guard loadError == nil else { return .unavailable }
        return observations.contains { $0.speciesID == speciesID } ? .logged : .notLogged
    }

    func observations(for speciesID: String) -> [Observation] {
        observations.filter { $0.speciesID == speciesID }.sorted {
            if $0.observedAt != $1.observedAt { return $0.observedAt > $1.observedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func exportData() throws -> Data {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(observations)
    }
}
