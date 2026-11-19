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
    init(service: any PhotoIdentificationService = UnconfiguredPhotoIdentification()) { self.service = service }

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
    func clear() { requestID = UUID(); photo = nil; candidates = []; isLoading = false; message = nil }
}

// Log-spaced Goertzel bins produce a real compact sonogram without external DSP/model dependencies.
enum SonogramAnalysis {
    static func column(samples: [Float], sampleRate: Double, bins: Int = 32) -> [Float] {
        guard sampleRate.isFinite, sampleRate > 1000, bins > 1, !samples.isEmpty else { return [] }
        let upper = min(10_000.0, sampleRate * 0.45)
        return (0..<bins).map { bin in
            let frequency = 250 * pow(upper / 250, Double(bin) / Double(bins - 1))
            let coefficient = 2 * cos(2 * Double.pi * frequency / sampleRate)
            var previous = 0.0, beforePrevious = 0.0
            for (index, sample) in samples.enumerated() {
                let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(max(1, samples.count - 1)))
                let value = Double(sample) * window + coefficient * previous - beforePrevious
                beforePrevious = previous; previous = value
            }
            let power = max(0, previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious)
            let amplitude = sqrt(power) / Double(samples.count)
            let decibels = 20 * log10(max(amplitude, 0.000001))
            return Float(min(1, max(0, (decibels + 80) / 65)))
        }
    }
}
