import Foundation
import Combine
import SwiftUI
@preconcurrency import AVFoundation

struct BirdAudioRecording: Identifiable, Sendable {
    let id: String
    let speciesID: String
    let speciesName: String
    let playbackURL: URL
    let sourceURL: URL
    let artist: String
    let license: String
    let licenseURL: URL
}

protocol SpeciesAudioRepository: Sendable {
    func recording(for species: Species) async throws -> BirdAudioRecording?
}

// Public Commons metadata API; no Xeno-canto/eBird key or scraped web pages.
// Files must identify the exact scientific name, have usable attribution and an
// explicitly supported free license, and provide an iOS-native audio rendition.
struct CommonsSpeciesAudioRepository: SpeciesAudioRepository {
    private struct Response: Decodable {
        struct Query: Decodable { let pages: [String: Page]? }
        let query: Query?
        let error: APIError?
        struct APIError: Decodable { let code: String }
    }
    private struct Page: Decodable {
        let pageid: Int
        let title: String
        let index: Int?
        let videoinfo: [Media]?
    }
    private struct Media: Decodable {
        struct Attribute: Decodable {
            let value: String
            private enum CodingKeys: String, CodingKey { case value }
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                // Commons also returns numeric bookkeeping fields (e.g. its
                // metadata-extension version). They must not reject the page.
                value = (try? container.decode(String.self, forKey: .value)) ?? ""
            }
        }
        struct Derivative: Decodable { let src: String; let type: String }
        let url: String?
        let descriptionurl: String?
        let derivatives: [Derivative]?
        let extmetadata: [String: Attribute]?
    }

    static func request(for species: Species) -> URLRequest {
        var url = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        url.queryItems = [
            URLQueryItem(name: "action", value: "query"), URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "filetype:audio \"\(species.scientificName)\""),
            URLQueryItem(name: "gsrnamespace", value: "6"), URLQueryItem(name: "gsrlimit", value: "30"),
            URLQueryItem(name: "prop", value: "videoinfo"),
            URLQueryItem(name: "viprop", value: "url|derivatives|extmetadata")
        ]
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 20
        request.setValue("BirdingCompanion/0.1 (https://github.com/ezralathouwers/Bird; personal bird guide)", forHTTPHeaderField: "User-Agent")
        return request
    }

    func recording(for species: Species) async throws -> BirdAudioRecording? {
        let (data, response) = try await URLSession.shared.data(for: Self.request(for: species))
        try Task.checkCancellation()
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Self.decode(data, for: species)
    }

    static func decode(_ data: Data, for species: Species) throws -> BirdAudioRecording? {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.error == nil else { throw URLError(.badServerResponse) }
        let pages = (response.query?.pages ?? [:]).values.sorted {
            if $0.index != $1.index { return ($0.index ?? Int.max) < ($1.index ?? Int.max) }
            return $0.pageid < $1.pageid
        }
        for page in pages {
            let title = page.title.replacingOccurrences(of: "_", with: " ")
            // Exclude spoken-word pronunciation and matches found only in a file's
            // description. Do not guess identification from an English name.
            guard title.range(of: "(?<![A-Za-z])" + NSRegularExpression.escapedPattern(for: species.scientificName) + "(?![A-Za-z])",
                              options: [.regularExpression, .caseInsensitive]) != nil,
                  title.range(of: "pronunciation|spoken|\\bLL-Q|File:[a-z]{2,3}-", options: [.regularExpression, .caseInsensitive]) == nil,
                  let media = page.videoinfo?.first, let metadata = media.extmetadata else { continue }
            let artist = plainText(metadata["Artist"]?.value ?? "")
            let license = plainText(metadata["LicenseShortName"]?.value ?? "")
            let supported = ["CC BY 2.0", "CC BY 2.5", "CC BY 3.0", "CC BY 4.0",
                             "CC BY-SA 2.0", "CC BY-SA 2.5", "CC BY-SA 3.0", "CC BY-SA 4.0",
                             "CC0", "CC0 1.0", "Public domain"]
            guard !artist.isEmpty, supported.contains(license),
                  let licenseURL = trustedURL(metadata["LicenseUrl"]?.value, host: "creativecommons.org"),
                  let sourceURL = trustedURL(media.descriptionurl, host: "commons.wikimedia.org") else { continue }
            let original = trustedURL(media.url, host: "upload.wikimedia.org")
            let playableOriginal = original.flatMap { url in
                ["mp3", "m4a", "aac", "wav", "aif", "aiff"].contains(url.pathExtension.lowercased()) ? url : nil
            }
            // Vorbis/Opus .ogg is not assumed playable on the deployment target.
            // Commons often provides an official MP3 transcode for these files.
            let derivative = (media.derivatives ?? []).first {
                $0.type.lowercased().hasPrefix("audio/mpeg")
            }.flatMap { trustedURL($0.src, host: "upload.wikimedia.org") }
            guard let playback = derivative ?? playableOriginal else { continue }
            return BirdAudioRecording(id: "commons:\(page.pageid)", speciesID: species.id,
                speciesName: species.dutchName, playbackURL: playback, sourceURL: sourceURL,
                artist: artist, license: license, licenseURL: licenseURL)
        }
        return nil
    }

    private static func trustedURL(_ string: String?, host: String) -> URL? {
        guard let string, var url = URLComponents(string: string), url.scheme == "https", url.host == host else { return nil }
        url.queryItems = url.queryItems?.filter { !$0.name.hasPrefix("utm_") }
        return url.url
    }
    private static func plainText(_ value: String) -> String {
        value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Additional public source; exact species identity and the sound's own license
// are checked independently of an observation/photo license.
struct INaturalistSpeciesAudioRepository: SpeciesAudioRepository {
    private struct Response: Decodable { let results: [Record] }
    private struct Record: Decodable {
        struct Taxon: Decodable { let name: String; let rank: String; let is_active: Bool? }
        struct User: Decodable { let login: String }
        struct Sound: Decodable {
            let id: Int
            let license_code: String?
            let attribution: String?
            let file_url: String?
            let file_content_type: String?
            let hidden: Bool?
        }
        let id: Int
        let quality_grade: String
        let taxon: Taxon?
        let user: User
        let sounds: [Sound]
    }
    static func request(for species: Species) -> URLRequest {
        var url = URLComponents(string: "https://api.inaturalist.org/v1/observations")!
        url.queryItems = [URLQueryItem(name: "taxon_name", value: species.scientificName),
            URLQueryItem(name: "sounds", value: "true"), URLQueryItem(name: "quality_grade", value: "research"),
            URLQueryItem(name: "sound_license", value: "cc-by,cc-by-sa,cc0"),
            URLQueryItem(name: "per_page", value: "30")]
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 15
        request.setValue("BirdingCompanion/0.1 (https://github.com/ezralathouwers/Bird)", forHTTPHeaderField: "User-Agent")
        return request
    }
    func recording(for species: Species) async throws -> BirdAudioRecording? {
        let (data, response) = try await URLSession.shared.data(for: Self.request(for: species))
        try Task.checkCancellation()
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Self.decode(data, for: species)
    }
    static func decode(_ data: Data, for species: Species) throws -> BirdAudioRecording? {
        for record in try JSONDecoder().decode(Response.self, from: data).results {
            guard record.quality_grade == "research", let taxon = record.taxon,
                  taxon.name.caseInsensitiveCompare(species.scientificName) == .orderedSame,
                  taxon.rank == "species", taxon.is_active != false, !record.user.login.isEmpty else { continue }
            for sound in record.sounds {
                guard sound.hidden != true, let code = sound.license_code,
                      ["cc-by", "cc-by-sa", "cc0"].contains(code),
                      let string = sound.file_url, let url = URL(string: string), url.scheme == "https",
                      ["static.inaturalist.org", "inaturalist-open-data.s3.amazonaws.com"].contains(url.host ?? ""),
                      ["mp3", "m4a", "aac", "wav", "aif", "aiff"].contains(url.pathExtension.lowercased()),
                      sound.file_content_type?.hasPrefix("audio/") == true else { continue }
                let license = code == "cc0" ? "CC0 1.0" : (code == "cc-by" ? "CC BY 4.0" : "CC BY-SA 4.0")
                let licenseURL = URL(string: code == "cc0" ? "https://creativecommons.org/publicdomain/zero/1.0/" :
                    "https://creativecommons.org/licenses/\(code == "cc-by" ? "by" : "by-sa")/4.0/")!
                let attribution = sound.attribution?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let artist = code != "cc0" && !attribution.isEmpty ? attribution : record.user.login
                return BirdAudioRecording(id: "inaturalist:\(sound.id)", speciesID: species.id,
                    speciesName: species.dutchName, playbackURL: url,
                    sourceURL: URL(string: "https://www.inaturalist.org/observations/\(record.id)")!,
                    artist: artist, license: license, licenseURL: licenseURL)
            }
        }
        return nil
    }
}

struct SupplementedSpeciesAudioRepository: SpeciesAudioRepository {
    var primary: any SpeciesAudioRepository = CommonsSpeciesAudioRepository()
    var secondary: any SpeciesAudioRepository = INaturalistSpeciesAudioRepository()
    func recording(for species: Species) async throws -> BirdAudioRecording? {
        var primaryError: (any Error)?
        do {
            if let found = try await primary.recording(for: species) { return found }
        } catch {
            try Task.checkCancellation()
            primaryError = error
        }
        try Task.checkCancellation()
        let found = try await secondary.recording(for: species)
        if let found { return found }
        // A temporary primary failure must not become a cached absence.
        if let primaryError { throw primaryError }
        return nil
    }
}

actor CachedSpeciesAudioRepository: SpeciesAudioRepository {
    static let shared = CachedSpeciesAudioRepository()
    private struct Entry { let recording: BirdAudioRecording?; let expires: Date }
    private var entries: [String: Entry] = [:]
    func recording(for species: Species) async throws -> BirdAudioRecording? {
        let key = species.id + ":" + species.scientificName
        if let entry = entries[key], entry.expires > Date() { return entry.recording }
        let recording = try await SupplementedSpeciesAudioRepository().recording(for: species)
        try Task.checkCancellation()
        entries[key] = Entry(recording: recording, expires: Date().addingTimeInterval(recording == nil ? 600 : 86400))
        return recording
    }
}

// Per-record attribution is available in the app's existing Info/source screen,
// without opening a player or attribution dialog on every listen-button tap.
@MainActor
final class SpeciesAudioCredits: ObservableObject {
    static let shared = SpeciesAudioCredits()
    @Published private(set) var recordings: [BirdAudioRecording] = []
    func register(_ recording: BirdAudioRecording) {
        if !recordings.contains(where: { $0.id == recording.id }) { recordings.append(recording) }
    }
}

@MainActor
protocol SpeciesAudioPlayback: AnyObject {
    func startLoop(_ recording: BirdAudioRecording, onFailure: @escaping @MainActor @Sendable () -> Void) throws
    func stop()
}

@MainActor
final class NativeSpeciesAudioPlayback: SpeciesAudioPlayback {
    private var playbackID = UUID()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var loopObservation: NSKeyValueObservation?
    private var ownsAudioSession = false

    func startLoop(_ recording: BirdAudioRecording, onFailure: @escaping @MainActor @Sendable () -> Void) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        ownsAudioSession = true
        let queue = AVQueuePlayer()
        let loop = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: recording.playbackURL))
        let id = UUID()
        playbackID = id
        player = queue
        looper = loop
        loopObservation = loop.observe(\.status, options: [.new, .initial]) { [weak self] value, _ in
            let failed = value.status == .failed
            if failed {
                Task { @MainActor [weak self] in
                    guard self?.playbackID == id else { return }
                    onFailure()
                }
            }
        }
        queue.play()
    }
    func stop() {
        playbackID = UUID()
        player?.pause()
        looper?.disableLooping()
        loopObservation?.invalidate()
        loopObservation = nil
        player?.removeAllItems()
        looper = nil
        player = nil
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }
}

@MainActor
final class SpeciesAudioModel: ObservableObject {
    @Published private(set) var recording: BirdAudioRecording?
    @Published private(set) var isPlaying = false
    @Published var playbackError: String?
    private let repository: any SpeciesAudioRepository
    private let playback: any SpeciesAudioPlayback
    private var preparationID = UUID()
    private var playbackID = UUID()

    init(repository: any SpeciesAudioRepository = CachedSpeciesAudioRepository.shared,
         playback: any SpeciesAudioPlayback = NativeSpeciesAudioPlayback()) {
        self.repository = repository
        self.playback = playback
    }
    func prepare(for species: Species) async {
        stop()
        recording = nil
        playbackError = nil
        let id = UUID()
        preparationID = id
        do {
            let candidate = try await repository.recording(for: species)
            guard preparationID == id, !Task.isCancelled else { return }
            recording = candidate
            if let candidate { SpeciesAudioCredits.shared.register(candidate) }
        } catch {
            // Unknown/offline availability never creates a nonfunctional button.
            guard preparationID == id, !Task.isCancelled else { return }
            recording = nil
        }
    }
    func toggle() {
        if isPlaying { stop(); return }
        guard let recording else { return }
        playbackError = nil
        let id = UUID()
        playbackID = id
        do {
            try playback.startLoop(recording) { [weak self] in
                guard let self, self.playbackID == id else { return }
                self.stop()
                self.playbackError = "Deze opname kon niet worden afgespeeld. Probeer het later opnieuw."
            }
            isPlaying = true
        } catch {
            stop()
            playbackError = "Deze opname kan nu niet worden afgespeeld. Controleer je verbinding en probeer het later opnieuw."
        }
    }
    func stop() {
        playbackID = UUID()
        playback.stop()
        isPlaying = false
    }
    func leavePage() {
        preparationID = UUID()
        stop()
    }
}


private struct SpeciesAudioAllowedKey: EnvironmentKey {
    static let defaultValue = true
}
extension EnvironmentValues {
    var speciesAudioIsAllowed: Bool {
        get { self[SpeciesAudioAllowedKey.self] }
        set { self[SpeciesAudioAllowedKey.self] = newValue }
    }
}
