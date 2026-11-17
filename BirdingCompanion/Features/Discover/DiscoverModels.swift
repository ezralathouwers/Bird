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
    let latitude: Double
    let longitude: Double
    let now: Date
    let radiusKilometers: Double
    var start: Date { now.addingTimeInterval(-30 * 24 * 60 * 60) }
}

// One species on one reviewed checklist, not the number of individual birds.
struct NearbyReport: Sendable {
    let checklistID: String
    let species: Species
    let observedAt: Date
    let latitude: Double
    let longitude: Double
}

struct DiscoverSpecies: Identifiable, Sendable {
    let species: Species
    let reportCount: Int
    var id: String { species.id }
}

struct DiscoverDataset: Sendable {
    let reports: [NearbyReport]
    let attribution: String
    let isDemo: Bool
    let coversRequestedWindow: Bool
}

protocol DiscoverRepository: Sendable {
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset
}

enum DiscoverDataError: LocalizedError {
    case notConfigured, incompleteFeed
    var errorDescription: String? {
        switch self {
        case .notConfigured: "Lokale vogelmeldingen zijn nog niet beschikbaar. Je kunt de voorbeeldpagina bekijken."
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
    static func ranked(_ reports: [NearbyReport], query: DiscoverQuery) -> [DiscoverSpecies] {
        let center = CLLocation(latitude: query.latitude, longitude: query.longitude)
        var species: [String: Species] = [:]
        var checklists: [String: Set<String>] = [:]
        for report in reports {
            guard !report.checklistID.isEmpty,
                  report.observedAt >= query.start, report.observedAt <= query.now,
                  report.latitude.isFinite, report.longitude.isFinite,
                  (-90...90).contains(report.latitude), (-180...180).contains(report.longitude) else { continue }
            let point = CLLocation(latitude: report.latitude, longitude: report.longitude)
            guard point.distance(from: center) <= query.radiusKilometers * 1000 else { continue }
            species[report.species.id] = report.species
            checklists[report.species.id, default: []].insert(report.checklistID)
        }
        return species.values.map {
            DiscoverSpecies(species: $0, reportCount: checklists[$0.id]?.count ?? 0)
        }.sorted {
            if $0.reportCount != $1.reportCount { return $0.reportCount > $1.reportCount }
            let left = $0.species.dutchName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            let right = $1.species.dutchName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            if left != right { return left < right }
            return $0.id < $1.id
        }
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
        Species(id: "sample-turdus-merula", taxonomyVersion: "mock-v1", dutchName: "Merel", englishName: "Common blackbird", scientificName: "Turdus merula"),
        Species(id: "sample-parus-major", taxonomyVersion: "mock-v1", dutchName: "Koolmees", englishName: "Great tit", scientificName: "Parus major"),
        Species(id: "sample-erithacus-rubecula", taxonomyVersion: "mock-v1", dutchName: "Roodborst", englishName: "European robin", scientificName: "Erithacus rubecula"),
        Species(id: "sample-cyanistes-caeruleus", taxonomyVersion: "mock-v1", dutchName: "Pimpelmees", englishName: "Eurasian blue tit", scientificName: "Cyanistes caeruleus"),
        Species(id: "sample-dendrocopos-major", taxonomyVersion: "mock-v1", dutchName: "Grote bonte specht", englishName: "Great spotted woodpecker", scientificName: "Dendrocopos major"),
        MockSpeciesRepository.kingfisher
    ]
}

struct DemoDiscoverRepository: DiscoverRepository {
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        let reports = DiscoverFixtures.catalog.enumerated().flatMap { index, species in
            (0..<(12 - index * 2)).map { number in
                NearbyReport(checklistID: "demo-\(index)-\(number)", species: species,
                    observedAt: query.now.addingTimeInterval(-Double(number + 1) * 86400),
                    latitude: query.latitude, longitude: query.longitude)
            }
        }
        return DiscoverDataset(reports: reports, attribution: "Fictieve voorbeeldmeldingen · geen eBird-data", isDemo: true, coversRequestedWindow: true)
    }
}
