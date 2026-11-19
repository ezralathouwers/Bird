import Foundation

struct BirdFamily: Identifiable, Hashable, Sendable {
    let id: String
    let dutchName: String

    static let thrushes = BirdFamily(id: "Turdidae", dutchName: "Lijsters")
    static let tits = BirdFamily(id: "Paridae", dutchName: "Mezen")
    static let flycatchers = BirdFamily(id: "Muscicapidae", dutchName: "Vliegenvangers")
    static let woodpeckers = BirdFamily(id: "Picidae", dutchName: "Spechten")
    static let kingfishers = BirdFamily(id: "Alcedinidae", dutchName: "IJsvogels")
    static let unknown = BirdFamily(id: "unclassified", dutchName: "Familie onbekend")
}

enum LogbookSort: String, CaseIterable {
    case family, lastLogged
    var label: String { self == .family ? "Per familie" : "Laatst ontdekt" }
}

struct LoggedSpecies: Identifiable, Sendable {
    let species: Species
    let firstObservedAt: Date
    var id: String { species.id }
}

struct LoggedFamily: Identifiable, Sendable {
    let family: BirdFamily
    let species: [LoggedSpecies]
    var id: String { family.id }
}

struct LogbookProjection {
    static func species(observations: [Observation], catalog: [Species], sort: LogbookSort) -> [LoggedSpecies] {
        var earliest: [String: Observation] = [:]
        for observation in observations {
            if let existing = earliest[observation.speciesID], existing.observedAt <= observation.observedAt { continue }
            earliest[observation.speciesID] = observation
        }
        let known = catalog.reduce(into: [String: Species]()) { $0[$1.id] = $1 }
        return earliest.values.map { record in
            let bird = known[record.speciesID] ?? BirdNETSpeciesLookup.species(id: record.speciesID) ?? Species(id: record.speciesID, taxonomyVersion: record.taxonomyVersion,
                dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
            return LoggedSpecies(species: bird, firstObservedAt: record.observedAt)
        }.sorted {
            if sort == .lastLogged, $0.firstObservedAt != $1.firstObservedAt { return $0.firstObservedAt > $1.firstObservedAt }
            return nameComesBefore($0.species, $1.species)
        }
    }

    static func families(from rows: [LoggedSpecies]) -> [LoggedFamily] {
        let grouped = Dictionary(grouping: rows) { $0.species.family ?? .unknown }
        return grouped.map { family, birds in
            LoggedFamily(family: family, species: birds.sorted { nameComesBefore($0.species, $1.species) })
        }.sorted {
            if $0.family == .unknown { return false }
            if $1.family == .unknown { return true }
            let comparison = $0.family.dutchName.compare($1.family.dutchName,
                options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    private static func nameComesBefore(_ left: Species, _ right: Species) -> Bool {
        let comparison = left.dutchName.compare(right.dutchName,
            options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
        return comparison == .orderedSame ? left.id < right.id : comparison == .orderedAscending
    }
}
