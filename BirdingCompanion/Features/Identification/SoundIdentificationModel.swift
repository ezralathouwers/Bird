import Foundation
import Combine
@preconcurrency import AVFoundation

// AVAudioFile is accessed only under this lock. PCM buffers never leave the audio callback.
private final class AudioCaptureSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var frames = 0
    init(url: URL, format: AVAudioFormat) throws { file = try AVAudioFile(forWriting: url, settings: format.settings) }
    func consume(_ buffer: AVAudioPCMBuffer) -> (column: [Float]?, error: String?) {
        lock.lock(); defer { lock.unlock() }
        guard let file else { return (nil, nil) }
        do { try file.write(from: buffer) }
        catch { self.file = nil; return (nil, "Opname opslaan mislukt. \(error.localizedDescription)") }
        frames += 1
        guard frames % 4 == 0, let channel = buffer.floatChannelData?[0] else { return (nil, nil) }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        return (SonogramAnalysis.column(samples: samples, sampleRate: buffer.format.sampleRate), nil)
    }
    func close() { lock.lock(); file = nil; lock.unlock() }
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
    @Published private(set) var candidates: [IdentificationCandidate] = []
    private var engine: AVAudioEngine?
    private var sink: AudioCaptureSink?
    private var generation = UUID()
    private let service: any SoundIdentificationService

    init(service: any SoundIdentificationService = UnconfiguredSoundIdentification()) { self.service = service }

    func start() async {
        guard !isRecording, !isStarting else { return }
        let id = UUID(); generation = id; isStarting = true
        let granted = await AVAudioApplication.requestRecordPermission()
        guard generation == id, !Task.isCancelled else { return }
        guard granted else { isStarting = false; message = "Sta microfoontoegang toe in Instellingen om Geluid-ID te gebruiken."; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let engine = AVAudioEngine()
            let format = engine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.fileReadUnknown) }
            let directory = URL.applicationSupportDirectory.appendingPathComponent("BirdingCompanion/Recordings", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(UUID().uuidString + ".caf")
            let sink = try AudioCaptureSink(url: url, format: format)
            self.engine = engine; self.sink = sink; recordingURL = url
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                let update = sink.consume(buffer)
                if update.column != nil || update.error != nil {
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == id, self.isRecording else { return }
                        if let error = update.error { self.stop(); self.message = error }
                        else if let column = update.column {
                            self.columns.append(column)
                            if self.columns.count > 100 { self.columns.removeFirst(self.columns.count - 100) }
                        }
                    }
                }
            }
            engine.prepare(); try engine.start()
            columns = []; candidates = []; duration = 0; startedAt = Date()
            isRecording = true; isStarting = false
            message = "De opname loopt. Automatische soortherkenning is nog niet aangesloten."
        } catch {
            stop(); message = "De microfoon kon niet worden gestart. \(error.localizedDescription)"
        }
    }

    func stop() {
        generation = UUID()
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        engine = nil; sink?.close(); sink = nil
        if isRecording, let startedAt { duration = max(0, Date().timeIntervalSince(startedAt)) }
        isRecording = false; isStarting = false; isIdentifying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func finishAndIdentify() async {
        stop()
        guard let recordingURL else { return }
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
