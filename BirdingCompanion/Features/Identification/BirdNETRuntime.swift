import Foundation
import CoreML
import CryptoKit
import ZIPFoundation
@preconcurrency import AVFoundation

struct BirdNETAssetConfiguration: Decodable {
    let version: String
    let modelURL: URL
    let modelSHA256: String
    let modelBytes: Int64
    let labelsSHA256: String
    let classCount: Int
}

enum BirdNETRuntimeError: LocalizedError {
    case missingAssets, checksum, download, invalidModel, invalidAudio
    var errorDescription: String? {
        switch self {
        case .missingAssets: "De BirdNET-modelgegevens ontbreken in deze appversie."
        case .checksum: "Het herkenningsmodel kon niet worden geverifieerd. Probeer het opnieuw."
        case .download: "Het herkenningsmodel kon niet worden opgehaald. Voor de eerste keer is internet nodig."
        case .invalidModel: "Dit herkenningsmodel kon niet worden geladen op dit apparaat."
        case .invalidAudio: "Dit geluidsfragment kon niet worden verwerkt."
        }
    }
}

// All Core ML access, resampling, downloads and compilation stay off the audio/main actors.
actor BirdNETCoreMLService: StreamingSoundIdentificationService {
    private var model: MLModel?
    private var labels: [BirdNETLabel] = []
    private var inputName = ""
    private var outputName = ""
    private var inputShape: [NSNumber] = []
    private var inputType: MLMultiArrayDataType = .float32
    private var classCount = 0
    private let threshold = 0.5

    func prepare() async throws {
        if model != nil { return }
        guard let configURL = Bundle.main.url(forResource: "BirdNETAssets", withExtension: "json"),
              let labelsURL = Bundle.main.url(forResource: "BirdNETLabels", withExtension: "json") else { throw BirdNETRuntimeError.missingAssets }
        let config = try JSONDecoder().decode(BirdNETAssetConfiguration.self, from: Data(contentsOf: configURL))
        let labelData = try Data(contentsOf: labelsURL)
        guard Self.hash(labelData) == config.labelsSHA256 else { throw BirdNETRuntimeError.checksum }
        let decoded = try JSONDecoder().decode([BirdNETLabel].self, from: labelData)
        guard Set(decoded.map(\.index)).count == decoded.count,
              decoded.allSatisfy({ (0..<config.classCount).contains($0.index) }) else { throw BirdNETRuntimeError.invalidModel }
        let root = URL.applicationSupportDirectory.appendingPathComponent("BirdingCompanion/Models", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var excludedRoot = root; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excludedRoot.setResourceValues(values)
        let installed = root.appendingPathComponent(config.version, isDirectory: true)
        let compiled = installed.appendingPathComponent("BirdNET.mlmodelc", isDirectory: true)
        let marker = installed.appendingPathComponent("source-sha256.txt")
        if !FileManager.default.fileExists(atPath: compiled.path) || (try? String(contentsOf: marker, encoding: .utf8)) != config.modelSHA256 {
            let workspace = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: workspace) }
            var request = URLRequest(url: config.modelURL); request.timeoutInterval = 600
            let (download, response) = try await URLSession.shared.download(for: request)
            defer { try? FileManager.default.removeItem(at: download) }
            if model != nil { return } // Another prepare call may have completed during this await.
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw BirdNETRuntimeError.download }
            try Task.checkCancellation()
            let size = try FileManager.default.attributesOfItem(atPath: download.path)[.size] as? NSNumber
            guard size?.int64Value == config.modelBytes, try Self.hashFile(download) == config.modelSHA256 else { throw BirdNETRuntimeError.checksum }
            let expanded = workspace.appendingPathComponent("expanded", isDirectory: true)
            try FileManager.default.unzipItem(at: download, to: expanded)
            try Task.checkCancellation()
            guard let enumerator = FileManager.default.enumerator(at: expanded, includingPropertiesForKeys: nil),
                  let package = enumerator.compactMap({ $0 as? URL }).first(where: { $0.pathExtension == "mlpackage" }) else {
                throw BirdNETRuntimeError.invalidModel
            }
            let temporaryCompiled = try Self.compile(package)
            defer { try? FileManager.default.removeItem(at: temporaryCompiled) }
            let staged = workspace.appendingPathComponent("installed", isDirectory: true)
            try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: temporaryCompiled, to: staged.appendingPathComponent("BirdNET.mlmodelc"))
            try config.modelSHA256.write(to: staged.appendingPathComponent("source-sha256.txt"), atomically: true, encoding: .utf8)
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: installed.path) { try FileManager.default.removeItem(at: installed) }
            try FileManager.default.moveItem(at: staged, to: installed)
        }
        let options = MLModelConfiguration(); options.computeUnits = .all
        let loaded = try MLModel(contentsOf: compiled, configuration: options)
        let inputs = loaded.modelDescription.inputDescriptionsByName
        guard inputs.count == 1, let input = inputs.first, let constraint = input.value.multiArrayConstraint,
              constraint.shape.map(\.intValue).reduce(1, *) == BirdNETAudio.sampleCount,
              let output = loaded.modelDescription.outputDescriptionsByName.first(where: {
                  $0.value.multiArrayConstraint?.shape.map(\.intValue).reduce(1, *) == config.classCount
              }) else { throw BirdNETRuntimeError.invalidModel }
        inputName = input.key; inputShape = constraint.shape; inputType = constraint.dataType
        outputName = output.key; classCount = config.classCount; labels = decoded; model = loaded
    }

    func identify(window: LiveAudioWindow) async throws -> [IdentificationCandidate] {
        try await prepare()
        try Task.checkCancellation()
        let samples = try BirdNETAudio.resampled(window)
        if BirdNETAudio.isSilent(samples) { return [] }
        guard let model else { throw BirdNETRuntimeError.invalidModel }
        let audio = try MLMultiArray(shape: inputShape, dataType: inputType)
        for (index, sample) in samples.enumerated() { audio[index] = NSNumber(value: sample) }
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(multiArray: audio)])
        let result = try await model.prediction(from: provider)
        try Task.checkCancellation()
        guard let scores = result.featureValue(for: outputName)?.multiArrayValue, scores.count == classCount else { throw BirdNETRuntimeError.invalidModel }
        return IdentificationCandidate.ranked(labels.compactMap { label in
            let score = scores[label.index].doubleValue
            return score.isFinite && score >= threshold && score <= 1 ? IdentificationCandidate(species: label.species, score: score) : nil
        })
    }

    func identify(recording: URL) async throws -> [IdentificationCandidate] {
        try await prepare()
        let file = try AVAudioFile(forReading: recording)
        let rate = file.processingFormat.sampleRate
        guard rate.isFinite, (8000...192000).contains(rate) else { throw BirdNETRuntimeError.invalidAudio }
        let count = AVAudioFrameCount(rate * 3)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: count) else { throw BirdNETRuntimeError.invalidAudio }
        var result: [IdentificationCandidate] = []
        let hop = AVAudioFramePosition(rate * 1.5)
        var position: AVAudioFramePosition = 0
        while position < file.length {
            try Task.checkCancellation(); file.framePosition = position
            try file.read(into: buffer, frameCount: count)
            let mono = try Self.mono(buffer)
            result = IdentificationCandidate.ranked(result + (try await identify(window: LiveAudioWindow(samples: mono, sampleRate: rate, endedAt: Date()))))
            position += max(1, hop)
        }
        return result
    }

    static func mono(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        guard let channels = buffer.floatChannelData else { throw BirdNETRuntimeError.invalidAudio }
        let channelCount = Int(buffer.format.channelCount), stride = buffer.stride
        return (0..<Int(buffer.frameLength)).map { frame in
            (0..<channelCount).reduce(Float(0)) { $0 + channels[$1][frame * stride] } / Float(channelCount)
        }
    }
    private static func compile(_ url: URL) throws -> URL { try MLModel.compileModel(at: url) }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func hashFile(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        var digest = SHA256()
        while let data = try file.read(upToCount: 1024 * 1024), !data.isEmpty { try Task.checkCancellation(); digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
