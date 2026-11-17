import Foundation

struct Species: Identifiable, Hashable, Sendable {
    let id: String
    let taxonomyVersion: String
    let dutchName: String
    let englishName: String
    let scientificName: String
    var family: BirdFamily? = nil

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
