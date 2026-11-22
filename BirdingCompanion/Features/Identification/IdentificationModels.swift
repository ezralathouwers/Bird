import Foundation
import Combine

struct IdentificationCandidate: Identifiable, Sendable {
    let species: Species
    let score: Double
    var id: String { species.id }

    static func ranked(_ input: [IdentificationCandidate]) -> [IdentificationCandidate] {
        var best: [String: IdentificationCandidate] = [:]
        for candidate in input where candidate.score.isFinite && (0...1).contains(candidate.score) {
            if let previous = best[candidate.id], previous.score >= candidate.score { continue }
            best[candidate.id] = candidate
        }
        return best.values.sorted {
            $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score
        }
    }
}

protocol PhotoIdentificationService: Sendable {
    func identify(photo: Data) async throws -> [IdentificationCandidate]
}
protocol SoundIdentificationService: Sendable {
    func identify(recording: URL) async throws -> [IdentificationCandidate]
}

enum IdentificationError: LocalizedError {
    case photoModelUnavailable, soundModelUnavailable, invalidPhoto
    var errorDescription: String? {
        switch self {
        case .photoModelUnavailable: "Fotoherkenning is nog niet aangesloten. Je foto is niet geüpload naar een herkenningsdienst."
        case .soundModelUnavailable: "Geluidsherkenning is nog niet aangesloten. De opname blijft lokaal; er worden nog geen vogelsoorten herkend."
        case .invalidPhoto: "Deze foto kon niet worden geopend. Kies een andere foto (maximaal 20 MB)."
        }
    }
}
struct UnconfiguredPhotoIdentification: PhotoIdentificationService {
    func identify(photo: Data) async throws -> [IdentificationCandidate] { throw IdentificationError.photoModelUnavailable }
}
struct UnconfiguredSoundIdentification: SoundIdentificationService {
    func identify(recording: URL) async throws -> [IdentificationCandidate] { throw IdentificationError.soundModelUnavailable }
}

@MainActor
final class PhotoIdentificationModel: ObservableObject {
    @Published private(set) var photo: Data?
    @Published private(set) var candidates: [IdentificationCandidate] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    private let service: any PhotoIdentificationService
    private var requestID = UUID()
    init(service: any PhotoIdentificationService = BioCLIPPhotoService()) { self.service = service }

    func identify(_ data: Data) async {
        let id = UUID(); requestID = id
        photo = nil; candidates = []; message = nil; isLoading = true
        guard !data.isEmpty, data.count <= 20 * 1024 * 1024 else {
            message = IdentificationError.invalidPhoto.localizedDescription; isLoading = false; return
        }
        photo = data
        defer { if requestID == id { isLoading = false } }
        do {
            let results = try await service.identify(photo: data)
            guard requestID == id, !Task.isCancelled else { return }
            candidates = IdentificationCandidate.ranked(results)
            if candidates.isEmpty { message = "Geen herkenningssuggesties gevonden. Probeer een andere foto." }
        } catch {
            guard requestID == id, !Task.isCancelled else { return }
            message = error.localizedDescription
        }
    }
    func cancel() { requestID = UUID(); isLoading = false }
    func clear() { requestID = UUID(); photo = nil; candidates = []; isLoading = false; message = nil }
}

// Log-spaced Goertzel bins produce a real compact sonogram without external DSP/model dependencies.
enum SonogramAnalysis {
    static func column(samples: [Float], sampleRate: Double, bins: Int = 32) -> [Float] {
        guard sampleRate.isFinite, sampleRate > 1000, bins > 1, !samples.isEmpty else { return [] }
        let upper = min(10_000.0, sampleRate * 0.45)
        let weighted = samples.enumerated().map { index, sample in
            Double(sample) * (0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(max(1, samples.count - 1))))
        }
        return (0..<bins).map { bin in
            let frequency = 250 * pow(upper / 250, Double(bin) / Double(bins - 1))
            let coefficient = 2 * cos(2 * Double.pi * frequency / sampleRate)
            var previous = 0.0, beforePrevious = 0.0
            for sample in weighted {
                let value = sample + coefficient * previous - beforePrevious
                beforePrevious = previous; previous = value
            }
            let power = max(0, previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious)
            let amplitude = sqrt(power) / Double(samples.count)
            let decibels = 20 * log10(max(amplitude, 0.000001))
            return Float(min(1, max(0, (decibels + 80) / 65)))
        }
    }
}

struct PinnedSoundSpecies: Codable, Equatable, Identifiable {
    let id: String
    let taxonomyVersion: String
    let dutchName: String
    let englishName: String
    let scientificName: String
    init(_ species: Species) {
        id = species.id; taxonomyVersion = species.taxonomyVersion
        dutchName = species.dutchName; englishName = species.englishName; scientificName = species.scientificName
    }
    var species: Species {
        Species(id: id, taxonomyVersion: taxonomyVersion, dutchName: dutchName,
            englishName: englishName, scientificName: scientificName)
    }
}

struct SoundResultRow: Identifiable {
    let species: Species
    let isPinned: Bool
    var id: String { species.id }
}

enum SoundResultOrdering {
    static func rows(candidates: [IdentificationCandidate], pins: [PinnedSoundSpecies]) -> [SoundResultRow] {
        let ranked = IdentificationCandidate.ranked(candidates)
        let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.id, $0.species) })
        var seen = Set<String>()
        var result: [SoundResultRow] = []
        for pin in pins where seen.insert(pin.id).inserted {
            result.append(SoundResultRow(species: byID[pin.id] ?? pin.species, isPinned: true))
        }
        for candidate in ranked where seen.insert(candidate.id).inserted {
            result.append(SoundResultRow(species: candidate.species, isPinned: false))
        }
        return result
    }
}

@MainActor
final class SoundResultPins: ObservableObject {
    @Published private(set) var species: [PinnedSoundSpecies] = []
    @Published private(set) var message: String?
    private let defaults: UserDefaults
    private let key = "sound-id-pinned-species-v1"
    private var loadFailed = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: key) else { return }
        do {
            let loaded = try JSONDecoder().decode([PinnedSoundSpecies].self, from: data)
            guard Set(loaded.map(\.id)).count == loaded.count,
                  loaded.allSatisfy({ !$0.id.isEmpty && !$0.taxonomyVersion.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
            species = loaded
        } catch {
            loadFailed = true
            message = "Vastgezette vogels konden niet worden geladen. De bewaarde voorkeuren blijven behouden."
        }
    }
    func toggle(_ bird: Species) {
        guard !loadFailed else { return }
        var updated = species
        if updated.contains(where: { $0.id == bird.id }) { updated.removeAll { $0.id == bird.id } }
        else { updated.append(PinnedSoundSpecies(bird)) }
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: key)
            species = updated
        } catch { message = "Deze vogel kon niet worden vastgezet. \(error.localizedDescription)" }
    }
}

struct SoundActivity {
    var lastHeard: [String: Date] = [:]
    mutating func heard(_ speciesID: String, at date: Date) {
        lastHeard[speciesID] = max(lastHeard[speciesID] ?? date, date)
    }
    func activeIDs(at date: Date, recording: Bool, hold: TimeInterval = 4) -> Set<String> {
        guard recording else { return [] }
        return Set(lastHeard.filter { date.timeIntervalSince($0.value) >= 0 && date.timeIntervalSince($0.value) < hold }.keys)
    }
}

// Model scores are independent multi-label scores, not calibrated probabilities.
// A weak candidate needs support in two of the last three analyzed windows.
struct SoundCandidateConfirmation {
    static let minimumScore = 0.15
    static let immediateScore = 0.35
    private var recent: [Set<String>] = []
    mutating func accept(_ results: [IdentificationCandidate]) -> [IdentificationCandidate] {
        let valid = IdentificationCandidate.ranked(results).filter { $0.score >= Self.minimumScore }
        recent.append(Set(valid.map(\.id)))
        if recent.count > 3 { recent.removeFirst(recent.count - 3) }
        return valid.filter { candidate in
            candidate.score >= Self.immediateScore || recent.filter { $0.contains(candidate.id) }.count >= 2
        }
    }
}
