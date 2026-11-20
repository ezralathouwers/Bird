import Foundation
import CoreML
import CryptoKit
import ZIPFoundation
import Accelerate
import UIKit
import ImageIO

struct BioCLIPAssets: Decodable {
    let modelURL: URL
    let packURL: URL
    let modelSHA256: String
    let packSHA256: String
    let labelsSHA256: String
}

enum PhotoRuntimeError: LocalizedError {
    case assets, download, checksum, schema
    var errorDescription: String? {
        switch self {
        case .assets: "De fotoherkenningsgegevens ontbreken in deze appversie."
        case .download: "Het fotomodel kon niet worden gedownload. De eerste keer is internet nodig (ongeveer 297 MB)."
        case .checksum: "De fotoherkenningsbestanden konden niet worden geverifieerd. Probeer het opnieuw."
        case .schema: "Het fotomodel kon niet worden geladen op dit apparaat."
        }
    }
}

// Similarity is not a calibrated probability. Unknown species, mammals and
// background rows compete with birds, so the classifier need not force a match.
enum PhotoSimilarity {
    static func normalized(_ input: [Float]) -> [Float]? {
        guard !input.isEmpty, input.allSatisfy(\.isFinite) else { return nil }
        let norm = sqrt(input.reduce(Float(0)) { $0 + $1 * $1 })
        guard norm.isFinite, norm > 0 else { return nil }
        return input.map { $0 / norm }
    }
    static func accepted(_ scores: [(String?, Float)], minimum: Float = 0.2, rejectionMargin: Float = 0.01) -> [(String, Float)] {
        let valid = scores.filter { $0.1.isFinite && (-1.001...1.001).contains($0.1) }
        let rejection = valid.filter { $0.0 == nil }.map(\.1).max() ?? -1
        var best: [String: Float] = [:]
        for (id, score) in valid {
            guard let id else { continue }
            best[id] = max(best[id] ?? -1, score)
        }
        let ranked = best.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        guard let first = ranked.first, first.value >= minimum, first.value >= rejection + rejectionMargin else { return [] }
        return ranked.filter { $0.value >= minimum && $0.value >= rejection + rejectionMargin }.prefix(5).map { ($0.key, $0.value) }
    }
}

actor BioCLIPPhotoService: PhotoIdentificationService {
    private var model: MLModel?
    private var vectors: [Float] = []
    private var labels: [String?] = []
    private var preparation: Task<Void, Error>?

    func identify(photo: Data) async throws -> [IdentificationCandidate] {
        try await prepare()
        try Task.checkCancellation()
        guard let model else { throw PhotoRuntimeError.schema }
        let pixels = try Self.pixels(photo)
        let result = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["pixels": MLFeatureValue(multiArray: pixels)]))
        guard let output = result.featureValue(for: "embedding")?.multiArrayValue, output.count == 768,
              let embedding = PhotoSimilarity.normalized((0..<768).map { output[$0].floatValue }) else { throw PhotoRuntimeError.schema }
        var scores: [(String?, Float)] = []
        vectors.withUnsafeBufferPointer { all in
            embedding.withUnsafeBufferPointer { image in
                for row in labels.indices {
                    var similarity: Float = 0
                    vDSP_dotpr(all.baseAddress! + row * 768, 1, image.baseAddress!, 1, &similarity, 768)
                    scores.append((labels[row], similarity))
                }
            }
        }
        try Task.checkCancellation()
        return PhotoSimilarity.accepted(scores).compactMap { id, similarity in
            guard let species = SpeciesGuideCatalog.species(id: id) else { return nil }
            return IdentificationCandidate(species: species, score: Double(min(1, max(0, (similarity + 1) / 2))))
        }
    }

    private func prepare() async throws {
        if model != nil { return }
        if let preparation { return try await preparation.value }
        let task = Task { try await self.install() }
        preparation = task
        defer { preparation = nil }
        try await task.value
    }

    private func install() async throws {
        guard let configURL = Bundle.main.url(forResource: "BioCLIPAssets", withExtension: "json"),
              let labelsURL = Bundle.main.url(forResource: "BioCLIPLabels", withExtension: "json") else { throw PhotoRuntimeError.assets }
        let config = try JSONDecoder().decode(BioCLIPAssets.self, from: Data(contentsOf: configURL))
        let labelData = try Data(contentsOf: labelsURL)
        guard Self.hash(labelData) == config.labelsSHA256 else { throw PhotoRuntimeError.checksum }
        let decoded = try JSONDecoder().decode([String?].self, from: labelData)
        guard decoded.count == 15331, decoded.compactMap({ $0 }).allSatisfy({ SpeciesGuideCatalog.species(id: $0) != nil }) else { throw PhotoRuntimeError.schema }
        let root = URL.applicationSupportDirectory.appendingPathComponent("BirdingCompanion/Models/BioCLIP2", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var excluded = root; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        let packURL = root.appendingPathComponent("labels.fpack")
        try await Self.download(config.packURL, to: packURL, sha256: config.packSHA256)
        let compiled = root.appendingPathComponent("image.mlmodelc", isDirectory: true)
        let marker = root.appendingPathComponent("image-sha256.txt")
        if !FileManager.default.fileExists(atPath: compiled.path) || (try? String(contentsOf: marker, encoding: .utf8)) != config.modelSHA256 {
            let archive = root.appendingPathComponent("image.zip")
            try await Self.download(config.modelURL, to: archive, sha256: config.modelSHA256)
            let scratch = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: scratch) }
            try FileManager.default.unzipItem(at: archive, to: scratch)
            let package = scratch.appendingPathComponent("bioclip2_image.mlpackage", isDirectory: true)
            let temporary = try MLModel.compileModel(at: package)
            defer { try? FileManager.default.removeItem(at: temporary) }
            if FileManager.default.fileExists(atPath: compiled.path) { try FileManager.default.removeItem(at: compiled) }
            try FileManager.default.moveItem(at: temporary, to: compiled)
            try config.modelSHA256.write(to: marker, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: archive)
        }
        let options = MLModelConfiguration(); options.computeUnits = .all
        let loaded = try MLModel(contentsOf: compiled, configuration: options)
        guard loaded.modelDescription.inputDescriptionsByName["pixels"]?.multiArrayConstraint?.dataType == .float16,
              loaded.modelDescription.inputDescriptionsByName["pixels"]?.multiArrayConstraint?.shape.map(\.intValue) == [1, 3, 224, 224],
              loaded.modelDescription.outputDescriptionsByName["embedding"]?.multiArrayConstraint?.shape.map(\.intValue) == [1, 768] else { throw PhotoRuntimeError.schema }
        let data = try Data(contentsOf: packURL)
        guard data.count > 8, Array(data.prefix(4)) == [70, 80, 75, 49] else { throw PhotoRuntimeError.schema }
        let headerSize = (0..<4).reduce(0) { $0 | Int(data[4 + $1]) << (8 * $1) }
        guard headerSize > 0, headerSize <= data.count - 8,
              let header = try JSONSerialization.jsonObject(with: data.subdata(in: 8..<(8 + headerSize))) as? [String: Any],
              header["rows"] as? Int == decoded.count, header["dim"] as? Int == 768,
              header["dtype"] as? String == "f16", data.count - 8 - headerSize == decoded.count * 768 * 2 else { throw PhotoRuntimeError.schema }
        var matrix: [Float] = []; matrix.reserveCapacity(decoded.count * 768)
        let start = 8 + headerSize
        for row in decoded.indices {
            let vector = (0..<768).map { column -> Float in
                let offset = start + (row * 768 + column) * 2
                return Float(Float16(bitPattern: UInt16(data[offset]) | UInt16(data[offset + 1]) << 8))
            }
            guard let normalized = PhotoSimilarity.normalized(vector) else { throw PhotoRuntimeError.schema }
            matrix.append(contentsOf: normalized)
        }
        vectors = matrix; labels = decoded; model = loaded
    }

    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func fileHash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private static func download(_ source: URL, to target: URL, sha256: String) async throws {
        if FileManager.default.fileExists(atPath: target.path), try fileHash(target) == sha256 { return }
        var request = URLRequest(url: source); request.timeoutInterval = 600
        let downloaded: URL; let response: URLResponse
        do { (downloaded, response) = try await URLSession.shared.download(for: request) }
        catch { throw PhotoRuntimeError.download }
        defer { try? FileManager.default.removeItem(at: downloaded) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PhotoRuntimeError.download }
        guard try fileHash(downloaded) == sha256 else { throw PhotoRuntimeError.checksum }
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
        try FileManager.default.moveItem(at: downloaded, to: target)
    }

    // Decode a bounded thumbnail and draw with orientation applied before RGB
    // conversion. Match CLIP's center crop, RGB channels, and mean/std exactly.
    static func pixels(_ photo: Data) throws -> MLMultiArray {
        guard let source = CGImageSourceCreateWithData(photo as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else { throw IdentificationError.invalidPhoto }
        var bytes = [UInt8](repeating: 0, count: 224 * 224 * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 224, height: 224, bitsPerComponent: 8,
                bytesPerRow: 224 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.interpolationQuality = .high
            // Quartz image draw uses a lower-left origin; flip to top-left RGB rows.
            context.translateBy(x: 0, y: 224); context.scaleBy(x: 1, y: -1)
            let scale = 224 / CGFloat(min(image.width, image.height))
            let width = CGFloat(image.width) * scale, height = CGFloat(image.height) * scale
            context.draw(image, in: CGRect(x: (224 - width) / 2, y: (224 - height) / 2, width: width, height: height))
            return true
        }
        guard drawn else { throw IdentificationError.invalidPhoto }
        let result = try MLMultiArray(shape: [1, 3, 224, 224], dataType: .float16)
        let mean: [Float] = [0.48145466, 0.4578275, 0.40821073]
        let std: [Float] = [0.26862954, 0.26130258, 0.27577711]
        for channel in 0..<3 {
            for pixel in 0..<(224 * 224) {
                result[channel * 224 * 224 + pixel] = NSNumber(value: (Float(bytes[pixel * 4 + channel]) / 255 - mean[channel]) / std[channel])
            }
        }
        return result
    }
}
