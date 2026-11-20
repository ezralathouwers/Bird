import SwiftUI
import MapKit
import Network

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
        switch source.access {
        case .awaitingPermission: throw RangeDataError.awaitingPermission
        case .approvedAwaitingFiles: throw RangeDataError.awaitingFiles
        case .licensed: break
        }
        let dataset = try BundledSpeciesRangeRepository(bundle: bundle).load(speciesID: speciesID)
        guard let version = source.datasetVersion, dataset.version == version,
              let citation = source.citation, let license = source.licenseNotice else { throw RangeDataError.invalid }
        return SpeciesRangeDataset(polygons: dataset.polygons, attribution: "\(citation) · \(license)", version: version)
    }
}

struct SpeciesRangeDataset {
    let polygons: [MKPolygon]
    let attribution: String
    let version: String
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
        var polygons: [MKPolygon] = []
        for feature in objects.compactMap({ $0 as? MKGeoJSONFeature }) {
            for geometry in feature.geometry {
                if let polygon = geometry as? MKPolygon { polygons.append(polygon) }
                else if let multi = geometry as? MKMultiPolygon { polygons.append(contentsOf: multi.polygons) }
                else { throw RangeDataError.invalid }
            }
        }
        guard !polygons.isEmpty else { throw RangeDataError.invalid }
        return SpeciesRangeDataset(polygons: polygons, attribution: "\(source) · \(license)", version: version)
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
    var repository: any SpeciesRangeRepository = ConfiguredSpeciesRangeRepository()
    @StateObject private var connectivity = MapConnectivity()
    @State private var source: SpeciesRangeSource?
    @State private var dataset: SpeciesRangeDataset?
    @State private var loading = true
    @State private var message: String?
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35, longitude: 60),
        span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 160)
    ))

    var body: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) {
            if let dataset {
                ForEach(dataset.polygons.indices, id: \.self) { index in
                    MapPolygon(dataset.polygons[index])
                        .foregroundStyle(FieldGuideTheme.taupe.opacity(0.25))
                        .stroke(FieldGuideTheme.taupe, lineWidth: 1)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                if loading { ProgressView("Verspreiding laden…") }
                if let message { Text(message) }
                if connectivity.isOffline { Text("Offline: de basiskaart is mogelijk onvolledig. Lokaal beschikbare verspreidingsdata blijft beschikbaar.") }
                if let dataset {
                    Text("Verspreidingsgebied · \(dataset.attribution) · \(dataset.version)")
                }
            }
            .font(FieldGuideTheme.sans(12, relativeTo: .caption))
            .padding(12)
            .background(FieldGuideTheme.ivory.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
            .padding(12)
            .accessibilityElement(children: .combine)
        }
        .accessibilityLabel("Interactieve verspreidingskaart van \(species.dutchName)")
        .task(id: species.id) { loadRange() }
    }

    private func loadRange() {
        loading = true
        dataset = nil
        message = nil
        source = try? SpeciesRangeSource.load()
        defer { loading = false }
        do {
            let loaded = try repository.load(speciesID: species.id)
            dataset = loaded
            let rect = loaded.polygons.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
            camera = .rect(rect.insetBy(dx: -rect.width * 0.08, dy: -rect.height * 0.08))
        } catch {
            switch error as? RangeDataError {
            case .awaitingFiles?, .awaitingPermission?, .unavailable?: message = nil
            default: message = "De kaartgegevens konden niet worden geladen."
            }
        }
    }
}
