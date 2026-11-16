import Foundation
import Combine

protocol ObservationPersistence {
    func load() throws -> [Observation]
    func save(_ observations: [Observation]) throws
}

struct JSONObservationPersistence: ObservationPersistence {
    let url: URL
    func load() throws -> [Observation] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Observation].self, from: Data(contentsOf: url))
    }
    func save(_ observations: [Observation]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(observations).write(to: url, options: .atomic)
    }
}

@MainActor
final class ObservationStore: ObservableObject {
    @Published private(set) var observations: [Observation] = []
    @Published private(set) var loadError: String?
    private let persistence: any ObservationPersistence

    init(persistence: any ObservationPersistence) {
        self.persistence = persistence
        do {
            let loaded = try persistence.load()
            for observation in loaded { try observation.validate() }
            guard Set(loaded.map(\.id)).count == loaded.count else { throw ObservationError.duplicateID }
            observations = loaded
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
        try persistence.save(updated)
        observations = updated
    }

    func exportData() throws -> Data {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(observations)
    }
}
