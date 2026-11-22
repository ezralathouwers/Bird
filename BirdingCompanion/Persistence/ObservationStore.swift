import Foundation
import Combine

protocol ObservationPersistence {
    func load() throws -> [Observation]
    func save(_ observations: [Observation]) throws
    func loadSessions() throws -> [BirdSession]
    func loadGoals() throws -> [BirdGoal]
    func save(_ observations: [Observation], sessions: [BirdSession], goals: [BirdGoal]) throws
    func save(_ observations: [Observation], sessions: [BirdSession]) throws
}

extension ObservationPersistence {
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

    // Final review replaces only this session's logs, preserving every other observation.
    func completeSession(_ review: BirdSession, logs: [Observation], expectedLogs: [Observation]) throws {
        guard let active = activeSession, active.id == review.id,
              let index = sessions.firstIndex(where: { $0.id == review.id }) else { throw SessionError.noActiveSession }
        let current = observations.filter { $0.sessionID == review.id }
        guard current.count == expectedLogs.count,
              current.allSatisfy({ expectedLogs.contains($0) }) else { throw SessionError.reviewChanged }
        guard review.isLive, review.endedAt != nil,
              logs.allSatisfy({ $0.sessionID == review.id }) else { throw SessionError.invalidSession }
        var updated = sessions; updated[index] = review
        try commit(observations: observations.filter { $0.sessionID != review.id } + logs, sessions: updated)
    }

    private func commit(observations: [Observation], sessions: [BirdSession]) throws {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try Self.validateArchive(observations: observations, sessions: sessions)
        try persistence.save(observations, sessions: sessions, goals: goals)
        self.observations = observations
        self.sessions = sessions
    }

    private static func validateArchive(observations: [Observation], sessions: [BirdSession]) throws {
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
