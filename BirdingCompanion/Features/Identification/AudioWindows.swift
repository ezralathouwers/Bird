import Foundation
@preconcurrency import AVFoundation

struct LiveAudioWindow: Sendable {
    let samples: [Float]
    let sampleRate: Double
    let endedAt: Date
}

// Bounded native-rate windows. Overlap is retained before any inference is scheduled.
struct AudioWindowAccumulator {
    private var samples: [Float] = []
    private(set) var sampleRate: Double = 0
    mutating func append(_ input: [Float], sampleRate: Double, endedAt: Date) -> LiveAudioWindow? {
        guard sampleRate.isFinite, sampleRate >= 8000, sampleRate <= 192000 else { return nil }
        if self.sampleRate != sampleRate { samples = []; self.sampleRate = sampleRate }
        let size = Int(sampleRate * 3), hop = Int(sampleRate * 1.5)
        samples.append(contentsOf: input)
        guard samples.count >= size else { return nil }
        // If a caller supplies an oversized chunk, prefer its most recent complete window.
        if samples.count > size + hop { samples.removeFirst(samples.count - size) }
        let window = Array(samples.prefix(size))
        samples.removeFirst(min(hop, samples.count))
        return LiveAudioWindow(samples: window, sampleRate: sampleRate, endedAt: endedAt)
    }
    var bufferedCount: Int { samples.count }
}

protocol StreamingSoundIdentificationService: SoundIdentificationService {
    func prepare() async throws
    func identify(window: LiveAudioWindow) async throws -> [IdentificationCandidate]
}

enum BirdNETAudio {
    static let sampleCount = 96000
    static func resampled(_ window: LiveAudioWindow) throws -> [Float] {
        guard !window.samples.isEmpty, window.samples.allSatisfy(\.isFinite),
              window.sampleRate.isFinite, (8000...192000).contains(window.sampleRate) else {
            throw BirdNETRuntimeError.invalidAudio
        }
        let samples: [Float]
        if window.sampleRate == 32000 { samples = window.samples }
        else {
            guard let source = AVAudioFormat(standardFormatWithSampleRate: window.sampleRate, channels: 1),
                  let target = AVAudioFormat(standardFormatWithSampleRate: 32000, channels: 1),
                  let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(window.samples.count)),
                  let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(sampleCount + 1024)),
                  let converter = AVAudioConverter(from: source, to: target) else { throw BirdNETRuntimeError.invalidAudio }
            input.frameLength = input.frameCapacity
            window.samples.withUnsafeBufferPointer { values in
                input.floatChannelData![0].update(from: values.baseAddress!, count: values.count)
            }
            converter.primeMethod = .none
            let feed = ConverterInputOnce(input)
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, state in feed.next(state) }
            if let error { throw error }
            guard status != .error, output.frameLength > 0 else { throw BirdNETRuntimeError.invalidAudio }
            samples = Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
        }
        var result = Array(samples.prefix(sampleCount))
        if result.count < sampleCount { result.append(contentsOf: repeatElement(0, count: sampleCount - result.count)) }
        return result.map { min(1, max(-1, $0)) }
    }
    static func isSilent(_ samples: [Float]) -> Bool {
        guard !samples.isEmpty else { return true }
        let meanSquare = samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)
        return meanSquare < 0.00000001
    }
}


// The converter callback may be annotated Sendable; keep its one-shot state under a lock.
private final class ConverterInputOnce: @unchecked Sendable {
    private let lock = NSLock()
    private let buffer: AVAudioPCMBuffer
    private var supplied = false
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    func next(_ state: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        lock.lock(); defer { lock.unlock() }
        if supplied { state.pointee = .endOfStream; return nil }
        supplied = true; state.pointee = .haveData; return buffer
    }
}
