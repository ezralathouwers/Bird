import Foundation
import CoreLocation

enum DiscoverFilter: String, CaseIterable {
    case all, logged, notLogged
    var label: String {
        switch self {
        case .all: "Alle soorten"
        case .logged: "Gelogde soorten"
        case .notLogged: "Nog niet gelogde soorten"
        }
    }
}

struct DiscoverQuery: Sendable {
    static let defaultLookbackDays = 3
    static func validLookbackDays(_ value: Int) -> Int { min(14, max(1, value)) }
    static let nearbyRadiusKilometers: Double = 5
    static func validRadius(_ value: Double) -> Double {
        value.isFinite ? min(50, max(1, value)) : nearbyRadiusKilometers
    }
    let latitude: Double
    let longitude: Double
    let now: Date
    let radiusKilometers: Double
    let daysBack: Int
    init(latitude: Double, longitude: Double, now: Date, radiusKilometers: Double,
         daysBack: Int = DiscoverQuery.defaultLookbackDays) {
        self.latitude = latitude; self.longitude = longitude; self.now = now
        self.radiusKilometers = radiusKilometers
        self.daysBack = Self.validLookbackDays(daysBack)
    }
    var start: Date { now.addingTimeInterval(-Double(daysBack) * 24 * 60 * 60) }
}

// One species on one reviewed checklist, not the number of individual birds.
struct NearbyReport: Sendable {
    let checklistID: String
    let species: Species
    let observedAt: Date
    let latitude: Double
    let longitude: Double
    var observationURL: URL? = nil
    var localObservedAt: String? = nil
}

struct DiscoverSpecies: Identifiable, Sendable {
    let species: Species
    let reportCount: Int
    var observationURL: URL? = nil
    var id: String { species.id }
}

enum DiscoverOrdering: Sendable, Equatable {
    case checklistFrequency, providerRecency
}

struct DiscoverDataset: Sendable {
    let reports: [NearbyReport]
    let attribution: String
    let isDemo: Bool
    let coversRequestedWindow: Bool
    var ordering: DiscoverOrdering = .checklistFrequency
    var warning: String? = nil
}

protocol DiscoverRepository: Sendable {
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset
}

// Publish complete results from one source while the other is still loading.
protocol ProgressiveDiscoverRepository: DiscoverRepository {
    func reports(for query: DiscoverQuery, onUpdate: @escaping @Sendable (DiscoverDataset) async -> Void) async throws -> DiscoverDataset
}

enum DiscoverDataError: LocalizedError, Equatable {
    case notConfigured, incompleteFeed
    var errorDescription: String? {
        switch self {
        case .notConfigured: "Verbind eBird om vogelmeldingen in je omgeving op te halen."
        case .incompleteFeed: "Deze gegevens zijn onvolledig. Een betrouwbare rangschikking is nog niet beschikbaar."
        }
    }
}

struct UnconfiguredDiscoverRepository: DiscoverRepository {
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        throw DiscoverDataError.notConfigured
    }
}

struct DiscoverRanking {
    static func ranked(_ reports: [NearbyReport], query: DiscoverQuery,
                       ordering: DiscoverOrdering = .checklistFrequency) -> [DiscoverSpecies] {
        let center = CLLocation(latitude: query.latitude, longitude: query.longitude)
        var species: [String: Species] = [:]
        var checklists: [String: Set<String>] = [:]
        // eBird sorts by observation recency before sending the response. Retain
        // that order: obsDt has no timezone and some records contain only a date.
        var firstPosition: [String: Int] = [:]
        var firstURL: [String: URL] = [:]
        for (position, report) in reports.enumerated() {
            guard !report.checklistID.isEmpty,
                  report.observedAt >= query.start, report.observedAt <= query.now,
                  report.latitude.isFinite, report.longitude.isFinite,
                  (-90...90).contains(report.latitude), (-180...180).contains(report.longitude) else { continue }
            let point = CLLocation(latitude: report.latitude, longitude: report.longitude)
            guard point.distance(from: center) <= query.radiusKilometers * 1000 else { continue }
            if firstPosition[report.species.id] == nil {
                firstPosition[report.species.id] = position
            }
            if firstURL[report.species.id] == nil {
                firstURL[report.species.id] = report.observationURL ?? checklistURL(report.checklistID)
            }
            species[report.species.id] = report.species
            checklists[report.species.id, default: []].insert(report.checklistID)
        }
        return species.values.map {
            DiscoverSpecies(species: $0, reportCount: checklists[$0.id]?.count ?? 0,
                            observationURL: firstURL[$0.id])
        }.sorted {
            if ordering == .providerRecency {
                return firstPosition[$0.id, default: Int.max] < firstPosition[$1.id, default: Int.max]
            }
            if ordering == .checklistFrequency && $0.reportCount != $1.reportCount { return $0.reportCount > $1.reportCount }
            let left = $0.species.dutchName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            let right = $1.species.dutchName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            if left != right { return left < right }
            return $0.id < $1.id
        }
    }

    static func checklistURL(_ id: String?) -> URL? {
        guard let id, id.range(of: "^S[0-9]+$", options: .regularExpression) != nil else { return nil }
        return URL(string: "https://ebird.org/checklist/" + id + "?siteLanguage=nl&locale=nl")
    }

    static func filtered(_ rows: [DiscoverSpecies], filter: DiscoverFilter,
                         observations: [Observation], statusAvailable: Bool = true) -> [DiscoverSpecies] {
        guard filter != .all else { return rows }
        guard statusAvailable else { return [] }
        let logged = Set(observations.map(\.speciesID))
        return rows.filter { filter == .logged ? logged.contains($0.id) : !logged.contains($0.id) }
    }
}

// Explicitly fictional catalog and checklist counts; no production taxonomy chosen.
enum DiscoverFixtures {
    static let catalog: [Species] = [
        Species(id: "sample-turdus-merula", taxonomyVersion: "mock-v1", dutchName: "Merel", englishName: "Common blackbird", scientificName: "Turdus merula", family: .thrushes),
        Species(id: "sample-parus-major", taxonomyVersion: "mock-v1", dutchName: "Koolmees", englishName: "Great tit", scientificName: "Parus major", family: .tits),
        Species(id: "sample-erithacus-rubecula", taxonomyVersion: "mock-v1", dutchName: "Roodborst", englishName: "European robin", scientificName: "Erithacus rubecula", family: .flycatchers),
        Species(id: "sample-cyanistes-caeruleus", taxonomyVersion: "mock-v1", dutchName: "Pimpelmees", englishName: "Eurasian blue tit", scientificName: "Cyanistes caeruleus", family: .tits),
        Species(id: "sample-dendrocopos-major", taxonomyVersion: "mock-v1", dutchName: "Grote bonte specht", englishName: "Great spotted woodpecker", scientificName: "Dendrocopos major", family: .woodpeckers),
        MockSpeciesRepository.kingfisher
    ]
}

struct DemoDiscoverRepository: DiscoverRepository {
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        let reports = DiscoverFixtures.catalog.enumerated().flatMap { index, species in
            (0..<(12 - index * 2)).map { number in
                NearbyReport(checklistID: "demo-\(index)-\(number)", species: species,
                    observedAt: query.now.addingTimeInterval(-Double(number + 1) / 12 * Double(query.daysBack) * 86400),
                    latitude: query.latitude, longitude: query.longitude)
            }
        }
        return DiscoverDataset(reports: reports, attribution: "Fictieve voorbeeldmeldingen · geen eBird-data", isDemo: true, coversRequestedWindow: true)
    }
}
