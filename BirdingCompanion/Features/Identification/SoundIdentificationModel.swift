import Foundation
import Combine
@preconcurrency import AVFoundation

struct CapturedAudioChunk: Sendable {
    let samples: [Float]
    let sampleRate: Double
    let endedAt: Date
}
struct CapturedAudioUpdate: Sendable {
    let column: [Float]?
    let window: LiveAudioWindow?
}
private enum CaptureError: LocalizedError {
    case unavailable, overrun
    var errorDescription: String? {
        switch self {
        case .unavailable: "De microfoon levert geen bruikbaar geluid. Controleer je invoerapparaat en probeer opnieuw."
        case .overrun: "Het apparaat kon de opname niet tijdig verwerken. De opname is gestopt; probeer opnieuw."
        }
    }
}

// Hardware start/stop never runs on MainActor. The tap copies only small value
// arrays; neither file I/O, sonogram processing nor UI work runs on that callback.
private actor AudioCaptureController {
    static let shared = AudioCaptureController()
    private var engine: AVAudioEngine?
    private var currentID: UUID?
    private var continuation: AsyncThrowingStream<CapturedAudioChunk, Error>.Continuation?
    func start(id: UUID) throws -> AsyncThrowingStream<CapturedAudioChunk, Error> {
        try Task.checkCancellation()
        stopCurrent()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        let inputEngine = AVAudioEngine()
        let format = inputEngine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate.isFinite, (8000...192000).contains(format.sampleRate), format.channelCount > 0 else {
            try? session.setActive(false); throw CaptureError.unavailable
        }
        let pair = AsyncThrowingStream<CapturedAudioChunk, Error>.makeStream(bufferingPolicy: .bufferingNewest(64))
        let sink = pair.continuation
        let tap: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
            do {
                let chunk = CapturedAudioChunk(samples: try BirdNETCoreMLService.mono(buffer),
                    sampleRate: buffer.format.sampleRate, endedAt: Date())
                if case .dropped = sink.yield(chunk) { sink.finish(throwing: CaptureError.overrun) }
            } catch { sink.finish(throwing: error) }
        }
        currentID = id; engine = inputEngine; continuation = sink
        inputEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tap)
        do { inputEngine.prepare(); try inputEngine.start() }
        catch { stopCurrent(); throw error }
        return pair.stream
    }
    func stop(id: UUID) { if currentID == id { stopCurrent() } }
    private func stopCurrent() {
        continuation?.finish(); continuation = nil
        if let engine { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        engine = nil; currentID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

actor AudioCaptureProcessor {
    private let url: URL
    private var file: AVAudioFile?
    private var windows = AudioWindowAccumulator()
    private var lastColumnAt = Date.distantPast
    init(url: URL) { self.url = url }
    func consume(_ chunk: CapturedAudioChunk) throws -> CapturedAudioUpdate {
        try Task.checkCancellation()
        guard !chunk.samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: chunk.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunk.samples.count)) else {
            throw CaptureError.unavailable
        }
        if file == nil { file = try AVAudioFile(forWriting: url, settings: format.settings) }
        buffer.frameLength = buffer.frameCapacity
        chunk.samples.withUnsafeBufferPointer { values in
            buffer.floatChannelData![0].update(from: values.baseAddress!, count: values.count)
        }
        try file?.write(from: buffer)
        let window = windows.append(chunk.samples, sampleRate: chunk.sampleRate, endedAt: chunk.endedAt)
        var column: [Float]?
        if chunk.endedAt.timeIntervalSince(lastColumnAt) >= 0.1 {
            column = SonogramAnalysis.column(samples: chunk.samples, sampleRate: chunk.sampleRate)
            lastColumnAt = chunk.endedAt
        }
        return CapturedAudioUpdate(column: column, window: window)
    }
    func close() { file = nil }
}

@MainActor
final class SoundIdentificationModel: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var isIdentifying = false
    @Published private(set) var columns: [[Float]] = []
    @Published private(set) var recordingURL: URL?
    @Published private(set) var startedAt: Date?
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var message: String?
    @Published private(set) var activity = SoundActivity()
    @Published private(set) var candidates: [IdentificationCandidate] = []
    private let capture = AudioCaptureController.shared
    private var captureTask: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var lastAudioAt: Date?
    private var generation = UUID()
    private var preparationTask: Task<Void, Error>?
    private var liveTask: Task<Void, Never>?
    private let service: any SoundIdentificationService

    init(service: any SoundIdentificationService = BirdNETCoreMLService()) { self.service = service }

    func start() async {
        guard !isRecording, !isStarting else { return }
        let id = UUID(); generation = id; isStarting = true
        let granted = await AVAudioApplication.requestRecordPermission()
        guard generation == id, !Task.isCancelled else { return }
        guard granted else { isStarting = false; message = "Sta microfoontoegang toe in Instellingen om Geluid-ID te gebruiken."; return }
        do {
            if let streaming = service as? any StreamingSoundIdentificationService {
                message = "Herkenningsmodel voorbereiden. Eenmalig wordt ongeveer 157 MB opgehaald; daarna werkt Geluid-ID offline."
                let preparation = Task { try await streaming.prepare() }
                preparationTask = preparation
                try await preparation.value
                guard generation == id, !Task.isCancelled else { return }
                preparationTask = nil
            }
            let directory = URL.applicationSupportDirectory.appendingPathComponent("BirdingCompanion/Recordings", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(UUID().uuidString + ".caf")
            watchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, self.generation == id, self.isStarting, !Task.isCancelled else { return }
                self.stop(); self.message = CaptureError.unavailable.localizedDescription
            }
            let stream = try await capture.start(id: id)
            guard generation == id, !Task.isCancelled else { await capture.stop(id: id); return }
            watchdog?.cancel(); watchdog = nil
            let processor = AudioCaptureProcessor(url: url)
            recordingURL = url; columns = []; candidates = []; activity = SoundActivity()
            duration = 0; startedAt = Date(); lastAudioAt = nil
            isRecording = true; isStarting = false
            captureTask = Task { [weak self] in
                do {
                    for try await chunk in stream {
                        let update = try await processor.consume(chunk)
                        guard let self, self.generation == id, !Task.isCancelled else { break }
                        self.lastAudioAt = Date()
                        if let column = update.column {
                            self.columns.append(column)
                            if self.columns.count > 100 { self.columns.removeFirst(self.columns.count - 100) }
                        }
                        if let window = update.window { self.submit(window, generation: id, recording: url) }
                    }
                } catch {
                    if let self, self.generation == id, !Task.isCancelled {
                        self.stop(); self.message = "De opname is gestopt. \(error.localizedDescription)"
                    }
                }
                await processor.close()
            }
            watchdog = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    guard let self, self.generation == id, !Task.isCancelled else { return }
                    if AudioCaptureHealth.isStalled(startedAt: self.startedAt, lastAudioAt: self.lastAudioAt, now: Date()) {
                        self.stop(); self.message = CaptureError.unavailable.localizedDescription; return
                    }
                }
            }
            message = service is any StreamingSoundIdentificationService ? "Aan het luisteren naar vogels…" : "De opname loopt. Live herkenning is niet beschikbaar voor deze dienst."
        } catch {
            guard generation == id else { return }
            stop(); message = "Geluid-ID kon niet worden gestart. \(error.localizedDescription)"
        }
    }

    func stop() {
        let stoppingID = generation
        generation = UUID()
        captureTask?.cancel(); captureTask = nil
        watchdog?.cancel(); watchdog = nil
        Task { await capture.stop(id: stoppingID) }
        preparationTask?.cancel(); preparationTask = nil
        liveTask?.cancel(); liveTask = nil
        if isRecording, let startedAt { duration = max(0, Date().timeIntervalSince(startedAt)) }
        isRecording = false; isStarting = false; isIdentifying = false; activity = SoundActivity()
    }

    private func submit(_ window: LiveAudioWindow, generation id: UUID, recording: URL) {
        guard liveTask == nil, let streaming = service as? any StreamingSoundIdentificationService else { return }
        // One inference at a time; skip windows rather than accumulate a delayed queue.
        liveTask = Task { [weak self] in
            do {
                let results = try await streaming.identify(window: window)
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.receiveLiveDetections(results, detectedAt: window.endedAt, recording: recording)
                self.message = nil
            } catch {
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.message = "Herkenning tijdelijk niet beschikbaar. \(error.localizedDescription)"
            }
            if let self, self.generation == id { self.liveTask = nil }
        }
    }

    // Streaming adapters call this with a thresholded, timestamped window result.
    // A result from another recording can never light up the current session.
    func receiveLiveDetections(_ results: [IdentificationCandidate], detectedAt: Date, recording: URL) {
        guard isRecording, recordingURL == recording, let startedAt,
              detectedAt >= startedAt, detectedAt <= Date() else { return }
        let valid = IdentificationCandidate.ranked(results)
        for candidate in valid { activity.heard(candidate.id, at: detectedAt) }
        candidates = IdentificationCandidate.ranked(candidates + valid)
    }

    func finishAndIdentify() async {
        let finalizing = captureTask
        stop()
        let stoppedID = generation
        await finalizing?.value
        guard generation == stoppedID else { return }
        guard let recordingURL else { return }
        if service is any StreamingSoundIdentificationService {
            message = candidates.isEmpty ? "Geen herkenningssuggesties uit de live analyse." : nil
            return
        }
        let id = UUID(); generation = id; isIdentifying = true
        defer { if generation == id { isIdentifying = false } }
        do {
            let results = try await service.identify(recording: recordingURL)
            guard generation == id, !Task.isCancelled else { return }
            candidates = IdentificationCandidate.ranked(results)
            message = candidates.isEmpty ? "Geen herkenningssuggesties gevonden in deze opname." : nil
        } catch {
            guard generation == id, !Task.isCancelled else { return }
            message = error.localizedDescription
        }
    }
}

enum AudioCaptureHealth {
    static func isStalled(startedAt: Date?, lastAudioAt: Date?, now: Date) -> Bool {
        guard let reference = lastAudioAt ?? startedAt else { return false }
        return now.timeIntervalSince(reference) >= 5
    }
}
