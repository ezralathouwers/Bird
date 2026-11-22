import SwiftUI
import MapKit
import Network
import CryptoKit
import UIKit

// Provider configuration contains public metadata only, never credentials or GIS data.
struct SpeciesRangeSource: Codable, Equatable {
    enum Access: String, Codable { case awaitingPermission, approvedAwaitingFiles, licensed }
    let providerID: String
    let name: String
    let homepage: URL
    let requestURL: URL
    let termsURL: URL
    let access: Access
    let datasetVersion: String?
    let licenseNotice: String?
    let citation: String?

    static func decode(_ data: Data) throws -> Self {
        let source = try JSONDecoder().decode(Self.self, from: data)
        guard source.providerID == "birdlife-datazone", !source.name.isEmpty,
              [source.homepage, source.requestURL, source.termsURL].allSatisfy({
                  $0.scheme == "https" && $0.host == "datazone.birdlife.org"
              }) else { throw RangeDataError.invalid }
        if source.access == .licensed {
            guard [source.datasetVersion, source.licenseNotice, source.citation].allSatisfy({
                !($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) else { throw RangeDataError.invalid }
        }
        return source
    }

    static func load(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "SpeciesRangeSource", withExtension: "json") else {
            throw RangeDataError.invalid
        }
        return try decode(Data(contentsOf: url))
    }
}

// Approved access and a validated local release are separate states.
// DataZone's website is not used as a polygon API.
struct ConfiguredSpeciesRangeRepository: SpeciesRangeRepository {
    let bundle: Bundle
    init(bundle: Bundle = .main) { self.bundle = bundle }

    func load(speciesID: String) throws -> SpeciesRangeDataset {
        let source = try SpeciesRangeSource.load(bundle: bundle)
        if source.access != .awaitingPermission,
           let local = try PrivateBirdLifeRangeRepository(bundle: bundle).loadIfInstalled(speciesID: speciesID) {
            return local
        }
        switch source.access {
        case .awaitingPermission: throw RangeDataError.awaitingPermission
        case .approvedAwaitingFiles: throw RangeDataError.awaitingFiles
        case .licensed: break
        }
        let dataset = try BundledSpeciesRangeRepository(bundle: bundle).load(speciesID: speciesID)
        guard let version = source.datasetVersion, dataset.version == version,
              let citation = source.citation, let license = source.licenseNotice else { throw RangeDataError.invalid }
        return SpeciesRangeDataset(polygons: dataset.polygons, attribution: "\(citation) · \(license)", version: version, areas: dataset.areas)
    }
}

struct SpeciesRangeManifest: Decodable, Sendable {
    struct Entry: Decodable, Sendable { let file: String; let sha256: String }
    let formatVersion: Int
    let providerID: String
    let version: String
    let citation: String
    let license: String
    let files: [String: Entry]
}

// Folder-reference resources are populated only on the user's own Mac.
struct PrivateBirdLifeRangeRepository {
    let bundle: Bundle
    func diagnostic(speciesID: String) -> String {
        var lines = ["Soort-ID: \(speciesID)"]
        guard let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "PrivateBirdLifeRanges") else {
            lines.append("Privékaartpakket in deze app: ontbreekt")
            lines.append("Kopieer de omgezette map PrivateBirdLifeRanges naar het project dat je bouwt en bouw opnieuw.")
            return lines.joined(separator: "\n")
        }
        do {
            let manifest = try JSONDecoder().decode(SpeciesRangeManifest.self, from: Data(contentsOf: url))
            lines.append("Kaartpakket: \(manifest.version), \(manifest.files.count) soorten")
            guard let entry = manifest.files[speciesID] else {
                lines.append("Deze soort staat niet in de export. Controleer conversion-report.json.")
                return lines.joined(separator: "\n")
            }
            let expected = speciesID.replacingOccurrences(of: ":", with: "-") + "-range.geojson"
            guard entry.file == expected, !entry.file.contains("/"), !entry.file.contains("..") else {
                lines.append("Bestandsverwijzing voor deze soort: ongeldig")
                return lines.joined(separator: "\n")
            }
            let file = url.deletingLastPathComponent().appendingPathComponent(entry.file)
            guard FileManager.default.fileExists(atPath: file.path) else {
                lines.append("Kaartbestand voor deze soort: ontbreekt in de app")
                return lines.joined(separator: "\n")
            }
            let data = try Data(contentsOf: file)
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            lines.append("Kaartbestand: \(data.count) bytes")
            lines.append("Bestandscontrole: \(hash == entry.sha256 ? "correct" : "wijkt af van export")")
            if let collection = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let features = collection["features"] as? [[String: Any]] {
                let current = features.filter { feature in
                    guard let attributes = feature["properties"] as? [String: Any],
                          let presence = attributes["presence"] as? Int,
                          let origin = attributes["origin"] as? Int else { return false }
                    return presence == 1 && [1, 2, 3, 6].contains(origin)
                }
                lines.append("Bronvlakken: \(features.count), huidig gevestigd: \(current.count)")
            }
            do {
                let decoded = try BundledSpeciesRangeRepository.decode(data)
                lines.append("Kaartdecode: \(decoded.polygons.count) polygonen")
            } catch {
                let diagnostic = error as NSError
                lines.append("Kaartdecode mislukt: \(diagnostic.domain) (\(diagnostic.code))")
            }
        } catch {
            lines.append("Kaartpakket kan niet worden gelezen.")
        }
        return lines.joined(separator: "\n")
    }

    func loadIfInstalled(speciesID: String) throws -> SpeciesRangeDataset? {
        guard let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "PrivateBirdLifeRanges") else { return nil }
        let manifest = try JSONDecoder().decode(SpeciesRangeManifest.self, from: Data(contentsOf: url))
        guard manifest.formatVersion == 1, manifest.providerID == "birdlife-datazone",
              manifest.version == "2025.2", !manifest.citation.isEmpty, !manifest.license.isEmpty else { throw RangeDataError.invalid }
        guard let entry = manifest.files[speciesID] else { throw RangeDataError.unavailable }
        let expected = speciesID.replacingOccurrences(of: ":", with: "-") + "-range.geojson"
        guard entry.file == expected, !entry.file.contains("/"), !entry.file.contains("..") else { throw RangeDataError.invalid }
        let data = try Data(contentsOf: url.deletingLastPathComponent().appendingPathComponent(entry.file))
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == entry.sha256,
              let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              metadata["speciesID"] as? String == speciesID,
              metadata["providerID"] as? String == "birdlife-datazone",
              metadata["citation"] as? String == manifest.citation,
              metadata["license"] as? String == manifest.license,
              metadata["version"] as? String == manifest.version else { throw RangeDataError.invalid }
        return try BundledSpeciesRangeRepository.decode(data)
    }
}

enum BirdLifeSeason: Int, CaseIterable {
    case resident = 1, breeding, nonBreeding, passage, uncertain
    var label: String {
        switch self {
        case .resident: "Jaarrond"
        case .breeding: "Broedgebied"
        case .nonBreeding: "Overwintering"
        case .passage: "Doortrek"
        case .uncertain: "Seizoen onbekend"
        }
    }
    var color: Color {
        switch self {
        case .resident: Color(red: 0.38, green: 0.50, blue: 0.36)
        case .breeding: Color(red: 0.70, green: 0.50, blue: 0.30)
        case .nonBreeding: Color(red: 0.36, green: 0.49, blue: 0.67)
        case .passage: Color(red: 0.56, green: 0.40, blue: 0.61)
        case .uncertain: FieldGuideTheme.taupe
        }
    }
}

struct SpeciesRangeArea {
    let polygon: MKPolygon
    let season: BirdLifeSeason?
    let origin: Int?
    var introduced: Bool { origin == 3 || origin == 6 }
}

struct SpeciesRangeDataset {
    let polygons: [MKPolygon]
    let attribution: String
    let version: String
    var areas: [SpeciesRangeArea] = []
    var mapRect: MKMapRect? = nil
}

enum RangeDataError: LocalizedError {
    case unavailable, invalid, awaitingPermission, awaitingFiles
    var errorDescription: String? {
        switch self {
        case .awaitingPermission: "BirdLife is ingesteld als bron. De verspreidingsgebieden zijn beschikbaar zodra toegang tot de gegevens is geregeld."
        case .awaitingFiles: "Toegang tot BirdLife is goedgekeurd. De verspreidingsbestanden zijn nog niet ingeladen."
        case .unavailable: "Nog geen gecontroleerd verspreidingsbestand beschikbaar voor deze soort."
        case .invalid: "Het verspreidingsbestand kon niet worden gelezen."
        }
    }
}

protocol SpeciesRangeRepository {
    func load(speciesID: String) throws -> SpeciesRangeDataset
}

struct BundledSpeciesRangeRepository: SpeciesRangeRepository {
    let bundle: Bundle
    init(bundle: Bundle = .main) { self.bundle = bundle }

    func load(speciesID: String) throws -> SpeciesRangeDataset {
        guard let url = bundle.url(forResource: speciesID + "-range", withExtension: "geojson") else {
            throw RangeDataError.unavailable
        }
        return try Self.decode(Data(contentsOf: url))
    }

    // Expected GeoJSON FeatureCollection: source, license and version at the top level.
    static func decode(_ data: Data) throws -> SpeciesRangeDataset {
        guard let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let source = metadata["source"] as? String, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let license = metadata["license"] as? String, !license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let version = metadata["version"] as? String, !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RangeDataError.invalid
        }
        let objects = try MKGeoJSONDecoder().decode(data)
        var areas: [SpeciesRangeArea] = []
        let birdLife = metadata["providerID"] as? String == "birdlife-datazone"
        for feature in objects.compactMap({ $0 as? MKGeoJSONFeature }) {
            var season: BirdLifeSeason?
            var origin: Int?
            if birdLife {
                guard let data = feature.properties,
                      let attributes = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let presence = attributes["presence"] as? Int,
                      let sourceOrigin = attributes["origin"] as? Int,
                      let seasonal = attributes["seasonal"] as? Int,
                      (1...6).contains(presence), (1...6).contains(sourceOrigin),
                      let sourceSeason = BirdLifeSeason(rawValue: seasonal) else { throw RangeDataError.invalid }
                // Current established ranges only; extinct, uncertain and vagrant
                // areas remain preserved in the private source but are not drawn.
                guard presence == 1, [1, 2, 3, 6].contains(sourceOrigin) else { continue }
                season = sourceSeason
                origin = sourceOrigin
            }
            for geometry in feature.geometry {
                let polygons: [MKPolygon]
                if let polygon = geometry as? MKPolygon { polygons = [polygon] }
                else if let multi = geometry as? MKMultiPolygon { polygons = multi.polygons }
                else { throw RangeDataError.invalid }
                areas += polygons.map { SpeciesRangeArea(polygon: $0, season: season, origin: origin) }
            }
        }
        guard !areas.isEmpty else { throw RangeDataError.unavailable }
        return SpeciesRangeDataset(polygons: areas.map(\.polygon),
            attribution: "\(metadata["citation"] as? String ?? source) · \(license)", version: version, areas: areas)
    }
}

// Only immutable coordinate values cross the background-loader actor boundary.
// MapKit objects stay on the main actor; no unchecked Sendable conformance.
struct SpeciesRangeSnapshot: Sendable {
    struct Point: Decodable, Sendable {
        let longitude: Double
        let latitude: Double
        init(from decoder: any Decoder) throws {
            var values = try decoder.unkeyedContainer()
            longitude = try values.decode(Double.self)
            latitude = try values.decode(Double.self)
            guard longitude.isFinite, latitude.isFinite,
                  (-180...180).contains(longitude), (-90...90).contains(latitude) else { throw RangeDataError.invalid }
        }
    }
    struct Polygon: Sendable {
        let rings: [[Point]]
        let season: Int?
        let origin: Int?
    }
    private struct Collection: Decodable {
        let type: String
        let source: String
        let license: String
        let version: String
        let citation: String?
        let providerID: String?
        let speciesID: String?
        let features: [Feature]
    }
    private struct Feature: Decodable {
        struct Attributes: Decodable { let presence: Int?; let origin: Int?; let seasonal: Int? }
        let type: String
        let properties: Attributes?
        let geometry: Geometry
    }
    private struct Geometry: Decodable {
        enum CodingKeys: CodingKey { case type, coordinates }
        let polygons: [[[Point]]]
        init(from decoder: any Decoder) throws {
            let value = try decoder.container(keyedBy: CodingKeys.self)
            switch try value.decode(String.self, forKey: .type) {
            case "Polygon": polygons = [try value.decode([[Point]].self, forKey: .coordinates)]
            case "MultiPolygon": polygons = try value.decode([[[Point]]].self, forKey: .coordinates)
            default: throw RangeDataError.invalid
            }
        }
    }
    let polygons: [Polygon]
    let attribution: String
    let version: String
    var coordinateCount: Int { polygons.reduce(0) { $0 + $1.rings.reduce(0) { $0 + $1.count } } }

    static func decode(_ data: Data, expectedSpeciesID: String? = nil,
                       expectedVersion: String? = nil, expectedCitation: String? = nil,
                       expectedLicense: String? = nil) throws -> Self {
        let collection = try JSONDecoder().decode(Collection.self, from: data)
        guard collection.type == "FeatureCollection",
              [collection.source, collection.license, collection.version].allSatisfy({
                  !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }) else { throw RangeDataError.invalid }
        if let expectedSpeciesID {
            guard collection.speciesID == expectedSpeciesID, collection.providerID == "birdlife-datazone",
                  collection.version == expectedVersion, collection.citation == expectedCitation,
                  collection.license == expectedLicense else { throw RangeDataError.invalid }
        }
        var polygons: [Polygon] = []
        for feature in collection.features {
            guard feature.type == "Feature" else { throw RangeDataError.invalid }
            var season: Int?
            var origin: Int?
            if collection.providerID == "birdlife-datazone" {
                guard let attributes = feature.properties, let presence = attributes.presence,
                      let sourceOrigin = attributes.origin, let seasonal = attributes.seasonal,
                      (1...6).contains(presence), (1...6).contains(sourceOrigin),
                      BirdLifeSeason(rawValue: seasonal) != nil else { throw RangeDataError.invalid }
                guard presence == 1, [1, 2, 3, 6].contains(sourceOrigin) else { continue }
                season = seasonal
                origin = sourceOrigin
            }
            for rings in feature.geometry.polygons {
                guard !rings.isEmpty, rings.allSatisfy({ $0.count >= 4 }) else { throw RangeDataError.invalid }
                polygons.append(Polygon(rings: rings, season: season, origin: origin))
            }
        }
        guard !polygons.isEmpty else { throw RangeDataError.unavailable }
        return Self(polygons: polygons, attribution: "\(collection.citation ?? collection.source) · \(collection.license)", version: collection.version)
    }
}

actor SpeciesRangeDataLoader {
    static let shared = SpeciesRangeDataLoader()
    private let bundle: Bundle
    private var source: SpeciesRangeSource?
    private var manifest: SpeciesRangeManifest?
    private var snapshots: [String: SpeciesRangeSnapshot] = [:]
    private var recency: [String] = []
    private var costs: [String: Int] = [:]
    init(bundle: Bundle = .main) { self.bundle = bundle }

    func load(speciesID: String) throws -> SpeciesRangeSnapshot {
        try Task.checkCancellation()
        if let cached = snapshots[speciesID] {
            touch(speciesID)
            return cached
        }
        let config: SpeciesRangeSource
        if let source { config = source }
        else { config = try SpeciesRangeSource.load(bundle: bundle); source = config }
        guard config.access != .awaitingPermission else { throw RangeDataError.awaitingPermission }
        let snapshot: SpeciesRangeSnapshot
        if let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "PrivateBirdLifeRanges") {
            let index: SpeciesRangeManifest
            if let manifest { index = manifest }
            else {
                index = try JSONDecoder().decode(SpeciesRangeManifest.self, from: Data(contentsOf: url))
                guard index.formatVersion == 1, index.providerID == "birdlife-datazone", index.version == "2025.2",
                      !index.citation.isEmpty, !index.license.isEmpty else { throw RangeDataError.invalid }
                manifest = index
            }
            guard let entry = index.files[speciesID] else { throw RangeDataError.unavailable }
            let expected = speciesID.replacingOccurrences(of: ":", with: "-") + "-range.geojson"
            guard entry.file == expected, !entry.file.contains("/"), !entry.file.contains("..") else { throw RangeDataError.invalid }
            let data = try Data(contentsOf: url.deletingLastPathComponent().appendingPathComponent(entry.file))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == entry.sha256 else { throw RangeDataError.invalid }
            snapshot = try SpeciesRangeSnapshot.decode(data, expectedSpeciesID: speciesID,
                expectedVersion: index.version, expectedCitation: index.citation, expectedLicense: index.license)
        } else {
            guard config.access == .licensed else { throw RangeDataError.awaitingFiles }
            guard let url = bundle.url(forResource: speciesID + "-range", withExtension: "geojson") else { throw RangeDataError.unavailable }
            let decoded = try SpeciesRangeSnapshot.decode(Data(contentsOf: url))
            guard decoded.version == config.datasetVersion,
                  let citation = config.citation, let license = config.licenseNotice else { throw RangeDataError.invalid }
            snapshot = SpeciesRangeSnapshot(polygons: decoded.polygons,
                attribution: "\(citation) · \(license)", version: decoded.version)
        }
        try Task.checkCancellation()
        snapshots[speciesID] = snapshot
        costs[speciesID] = snapshot.coordinateCount * 16
        touch(speciesID)
        while recency.count > 8 || costs.values.reduce(0, +) > 32 * 1024 * 1024 {
            let removed = recency.removeFirst()
            snapshots.removeValue(forKey: removed)
            costs.removeValue(forKey: removed)
        }
        return snapshot
    }
    private func touch(_ id: String) {
        recency.removeAll { $0 == id }
        recency.append(id)
    }
}

@MainActor
private enum SpeciesRangeDisplayCache {
    private final class Entry {
        let dataset: SpeciesRangeDataset
        init(_ dataset: SpeciesRangeDataset) { self.dataset = dataset }
    }
    private static let entries: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 8
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
    static func cached(speciesID: String) -> SpeciesRangeDataset? { entries.object(forKey: speciesID as NSString)?.dataset }
    static func display(_ snapshot: SpeciesRangeSnapshot, speciesID: String) -> SpeciesRangeDataset {
        if let cached = cached(speciesID: speciesID) { return cached }
        var areas: [SpeciesRangeArea] = []
        for polygon in snapshot.polygons {
            let holes = polygon.rings.dropFirst().map { ring -> MKPolygon in
                let points = ring.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                return points.withUnsafeBufferPointer { MKPolygon(coordinates: $0.baseAddress!, count: $0.count) }
            }
            guard let exterior = polygon.rings.first else { continue }
            let coordinates = exterior.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let native = coordinates.withUnsafeBufferPointer {
                MKPolygon(coordinates: $0.baseAddress!, count: $0.count, interiorPolygons: holes)
            }
            areas.append(SpeciesRangeArea(polygon: native, season: polygon.season.flatMap(BirdLifeSeason.init(rawValue:)), origin: polygon.origin))
        }
        let polygons = areas.map(\.polygon)
        let rect = polygons.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
        let dataset = SpeciesRangeDataset(polygons: polygons, attribution: snapshot.attribution,
            version: snapshot.version, areas: areas, mapRect: rect)
        entries.setObject(Entry(dataset), forKey: speciesID as NSString, cost: snapshot.coordinateCount * 32)
        return dataset
    }
}

@MainActor
final class MapConnectivity: ObservableObject {
    @Published private(set) var isOffline = false
    private let monitor = NWPathMonitor()
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status == .unsatisfied
            Task { @MainActor [weak self] in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "birding.map-connectivity"))
    }
    deinit { monitor.cancel() }
}

struct SpeciesDistributionMap: View {
    let species: Species
    var repository: (any SpeciesRangeRepository)? = nil
    var onExpand: (() -> Void)? = nil
    var isFullScreen = false
    @StateObject private var connectivity = MapConnectivity()
    @State private var source: SpeciesRangeSource?
    @State private var dataset: SpeciesRangeDataset?
    @State private var loading = true
    @State private var message: String?
    @State private var showSources = false
    @State private var showDiagnostics = false
    @State private var lastLoadFailure = ""
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35, longitude: 60),
        span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 160)
    ))

    var body: some View {
        ZStack {
            Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) {
                if let dataset {
                    ForEach(dataset.polygons.indices, id: \.self) { index in
                        MapPolygon(dataset.polygons[index])
                            .foregroundStyle(areaColor(dataset, index: index).opacity(0.38))
                            .stroke(areaColor(dataset, index: index).opacity(0.75), style: StrokeStyle(lineWidth: 0.8,
                                dash: dataset.areas.indices.contains(index) && dataset.areas[index].introduced ? [4, 3] : []))
                    }
                }
            }
            .mapStyle(FieldGuideTheme.mapStyle)
            .mapControls {
                if !isFullScreen { MapCompass() }
                MapScaleView()
            }
            .saturation(0.72)
            .ignoresSafeArea(edges: isFullScreen ? [.top, .bottom] : [])
            .onTapGesture { onExpand?() }
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                if let dataset {
                    Button { showSources = true } label: {
                        Text("BirdLife/HBW · \(dataset.version)")
                            .font(FieldGuideTheme.sans(10, relativeTo: .caption2))
                            .frame(minHeight: 44, alignment: .topLeading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(FieldGuideTheme.charcoal)
                    .accessibilityLabel(dataset.attribution)
                }
                if loading || message != nil || connectivity.isOffline {
                    VStack(alignment: .leading, spacing: 8) {
                        if loading { ProgressView("Verspreiding laden…") }
                        if let message {
                            Text(message)
                            Button("Kaartcontrole") { showDiagnostics = true }.frame(minHeight: 44)
                        }
                        if connectivity.isOffline { Text("Offline: de basiskaart is mogelijk onvolledig. Lokaal beschikbare verspreidingsdata blijft beschikbaar.") }
                    }
                    .font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    .padding(8)
                    .background(FieldGuideTheme.ivory.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(12)
        }
        .overlay(alignment: .bottomLeading) {
            if let dataset {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BirdLifeSeason.allCases.filter { season in dataset.areas.contains { $0.season == season } }, id: \.self) { season in
                            Label { Text(season.label) } icon: { Circle().fill(season.color).frame(width: 8, height: 8) }
                        }
                        if dataset.areas.contains(where: \.introduced) { Text("Stippellijn: geïntroduceerd") }
                    }
                    .font(FieldGuideTheme.sans(10, relativeTo: .caption2))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                }
                .background(FieldGuideTheme.mapLegendBackground, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, isFullScreen ? 20 : 8)
                .padding(.bottom, isFullScreen ? 44 : 24)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let onExpand {
                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 18, weight: .light))
                        .frame(width: 44, height: 44)
                        .background(FieldGuideTheme.ivory, in: Circle())
                }
                .accessibilityLabel("Open schermvullende verspreidingskaart")
                .padding(.trailing, 12).padding(.top, 12)
            }
        }
        .sheet(isPresented: $showSources) { SpeciesCatalogSourcesView() }
        .alert("Kaartcontrole", isPresented: $showDiagnostics) {
            Button("Kopieer controle") { UIPasteboard.general.string = diagnosticText }
            Button("Sluiten", role: .cancel) {}
        } message: { Text(diagnosticText) }
        .accessibilityLabel("Interactieve verspreidingskaart van \(species.dutchName)")
        .task(id: species.id) { await loadRange() }
    }

    private var diagnosticText: String {
        "\(species.dutchName)\n" + PrivateBirdLifeRangeRepository(bundle: .main).diagnostic(speciesID: species.id)
            + "\nLaadresultaat: \(lastLoadFailure)"
    }

    private func areaColor(_ dataset: SpeciesRangeDataset, index: Int) -> Color {
        dataset.areas.indices.contains(index) ? (dataset.areas[index].season?.color ?? FieldGuideTheme.taupe) : FieldGuideTheme.taupe
    }

    private func loadRange() async {
        loading = true
        dataset = nil
        message = nil
        lastLoadFailure = ""
        source = try? SpeciesRangeSource.load()
        defer { loading = false }
        do {
            let loaded: SpeciesRangeDataset
            if let repository { loaded = try repository.load(speciesID: species.id) }
            else if let cached = SpeciesRangeDisplayCache.cached(speciesID: species.id) { loaded = cached }
            else {
                let snapshot = try await SpeciesRangeDataLoader.shared.load(speciesID: species.id)
                try Task.checkCancellation()
                loaded = SpeciesRangeDisplayCache.display(snapshot, speciesID: species.id)
            }
            guard !Task.isCancelled else { return }
            dataset = loaded
            let rect = loaded.mapRect ?? loaded.polygons.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
            camera = .rect(rect.insetBy(dx: -rect.width * 0.08, dy: -rect.height * 0.08))
        } catch {
            guard !Task.isCancelled else { return }
            switch error as? RangeDataError {
            case .awaitingFiles?:
                message = "De omgezette kaarten ontbreken in deze app."
                lastLoadFailure = "geen lokaal kaartpakket meegebouwd"
            case .awaitingPermission?:
                message = RangeDataError.awaitingPermission.localizedDescription
                lastLoadFailure = "toegang niet geconfigureerd"
            case .unavailable?:
                message = "Voor deze soort is geen huidig verspreidingsgebied ingeladen."
                lastLoadFailure = "soort ontbreekt of heeft geen huidig gevestigd gebied"
            default:
                message = "De kaartgegevens konden niet worden geladen."
                lastLoadFailure = "lezen, bestandscontrole of GeoJSON-decodering mislukt"
            }
        }
    }
}


struct SpeciesRangeFullscreenView: View {
    let species: Species
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SpeciesDistributionMap(species: species, isFullScreen: true)
            .background(FieldGuideTheme.ivory.ignoresSafeArea())
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    SpeciesMapBadge(species: species)
                    MapCloseButton(label: "Sluit verspreidingskaart") { dismiss() }
                }
                .padding(.trailing, 20).padding(.top, 12)
            }
    }
}
