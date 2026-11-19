import Foundation

struct LoggedCountry: Identifiable, Hashable {
    let code: String
    let speciesCount: Int
    var id: String { code }
    var name: String { ObservationCountry.name(for: code) }
    var flag: String {
        String(String.UnicodeScalarView(code.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }))
    }
}

enum CountryProjection {
    static func observations(in code: String, from observations: [Observation]) -> [Observation] {
        guard let normalized = ObservationCountry.normalized(code) else { return [] }
        return observations.filter { ObservationCountry.normalized($0.countryCode) == normalized }
    }

    static func countries(in observations: [Observation]) -> [LoggedCountry] {
        var speciesByCountry: [String: Set<String>] = [:]
        for record in observations {
            guard let code = ObservationCountry.normalized(record.countryCode) else { continue }
            speciesByCountry[code, default: []].insert(record.speciesID)
        }
        return speciesByCountry.map { LoggedCountry(code: $0.key, speciesCount: $0.value.count) }.sorted {
            let comparison = $0.name.compare($1.name, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            return comparison == .orderedSame ? $0.code < $1.code : comparison == .orderedAscending
        }
    }
}
