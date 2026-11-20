import Foundation

struct Species: Identifiable, Hashable, Sendable {
    let id: String
    let taxonomyVersion: String
    let dutchName: String
    let englishName: String
    let scientificName: String
    var family: BirdFamily? = nil
    var aliases: [String] = []

    // Asset filenames are separate from persistent taxonomy/observation IDs.
    var artworkKey: String { id.replacingOccurrences(of: ":", with: "-") }

    var englishDisplayName: String {
        englishName.prefix(1).uppercased() + englishName.dropFirst().lowercased()
    }
}

protocol SpeciesRepository {
    var species: [Species] { get }
    func search(_ query: String) -> [Species]
}

struct MockSpeciesRepository: SpeciesRepository {
    static let kingfisher = Species(
        id: "sample-alcedo-atthis", taxonomyVersion: "mock-v1-not-a-taxonomic-authority",
        dutchName: "IJsvogel", englishName: "Common Kingfisher", scientificName: "Alcedo atthis", family: .kingfishers
    )
    let species = [kingfisher]
    func search(_ query: String) -> [Species] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return species.filter { bird in
            term.isEmpty || [bird.dutchName, bird.englishName, bird.scientificName]
                .contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }
}


// Five assets per species; the classic portrait is reserved for compact contexts.
enum SpeciesMediaRole: String, CaseIterable, Sendable {
    case classic = "primary"
    case dynamic = "dynamic"
    case front = "front"
    case rear = "rear"
    // Centered ventral view: head up, tail down, wings spread left/right.
    case flight = "flight"

    static let detailSlides: [SpeciesMediaRole] = [.dynamic, .front, .rear, .flight]
    func assetName(for species: Species) -> String { species.artworkKey + "-" + rawValue }
    var label: String {
        switch self {
        case .classic: "Klassieke illustratie"
        case .dynamic: "Dynamische illustratie"
        case .front: "Vooraanzicht"
        case .rear: "Achteraanzicht"
        case .flight: "Onderaanzicht in vlucht"
        }
    }
    var missingMessage: String { "" }
}


enum SpeciesCatalogSearch {
    static func results(for query: String, in catalog: [Species]) -> [Species] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.filter { bird in
            term.isEmpty || ([bird.dutchName, bird.englishName, bird.scientificName] + bird.aliases).contains {
                $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE")) != nil
            }
        }.sorted {
            let result = $0.dutchName.compare($1.dutchName, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            return result == .orderedSame ? $0.id < $1.id : result == .orderedAscending
        }
    }
}
