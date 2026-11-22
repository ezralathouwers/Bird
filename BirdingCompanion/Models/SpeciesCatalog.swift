import Foundation
import CryptoKit

struct BirdNETLabel: Decodable {
    let index: Int
    let birdnetID: String
    let scientificName: String
    let dutchName: String
    let englishName: String
    var species: Species {
        // Preserve existing internal IDs; other labels get an explicit external namespace.
        SpeciesGuideCatalog.species(birdnetID: birdnetID) ?? DiscoverFixtures.catalog.first { $0.scientificName == scientificName } ?? Species(
            id: "birdnet-v3:" + birdnetID, taxonomyVersion: "BirdNET+ labels v0.5-Nov2026",
            dutchName: dutchName.isEmpty ? englishName : dutchName,
            englishName: englishName, scientificName: scientificName)
    }
}


struct WorldSpeciesRecord: Decodable, Sendable {
    let id: String
    let birdnetID: String?
    let ebirdCode: String?
    let scientificName: String
    let dutchName: String
    let englishName: String
    let family: String
    let familyEnglish: String
    let order: String
    let aliases: [String]
    let extinction: String?
    let checklistSpecies: Bool
    let soundIndex: Int?

    var species: Species {
        if var sample = DiscoverFixtures.catalog.first(where: { $0.id == id }) {
            sample.aliases = aliases
            return sample
        }
        let knownFamilies: [BirdFamily] = [.thrushes, .tits, .flycatchers, .woodpeckers, .kingfishers]
        let group = knownFamilies.first { $0.id == family } ?? BirdFamily(id: family, dutchName: family)
        return Species(id: id, taxonomyVersion: soundIndex != nil ? "BirdNET+ labels v0.5-Nov2026" : "AviList v2026 / BirdNET+ taxonomy v0.5-Nov2026",
            dutchName: dutchName.isEmpty ? englishName.prefix(1).uppercased() + englishName.dropFirst().lowercased() : dutchName, englishName: englishName,
            scientificName: scientificName, family: group, aliases: aliases)
    }
}

struct SpeciesCatalogMetadata: Decodable, Sendable {
    let version: String
    let checklistSpecies: Int
    let records: Int
    let soundSpecies: Int
    let withoutSound: Int
    let missingDutch: Int
    let catalogSHA256: String
}

// Full AviList world coverage; sound support is a separate per-species capability.
enum SpeciesGuideCatalog {
    private struct Snapshot: Sendable {
        let birds: [Species]
        let byID: [String: Species]
        let byBirdNET: [String: Species]
        let records: [String: WorldSpeciesRecord]
        let metadata: SpeciesCatalogMetadata?
        let error: String?
    }
    private static let snapshot: Snapshot = {
        do {
            guard let url = Bundle.main.url(forResource: "WorldSpeciesCatalog", withExtension: "json"),
                  let meta = Bundle.main.url(forResource: "WorldSpeciesCatalogProvenance", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let data = try Data(contentsOf: url)
            let metadata = try JSONDecoder().decode(SpeciesCatalogMetadata.self, from: Data(contentsOf: meta))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == metadata.catalogSHA256 else { throw CocoaError(.fileReadCorruptFile) }
            let records = try JSONDecoder().decode([WorldSpeciesRecord].self, from: data)
            guard records.count == metadata.records, Set(records.map(\.id)).count == records.count,
                  records.filter(\.checklistSpecies).count == metadata.checklistSpecies,
                  records.filter({ $0.soundIndex != nil }).count == metadata.soundSpecies else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let birds = SpeciesCatalogSearch.results(for: "", in: records.map(\.species))
            let byID = Dictionary(uniqueKeysWithValues: birds.map { ($0.id, $0) })
            let pairs = records.compactMap { record -> (String, Species)? in
                guard let id = record.birdnetID else { return nil }
                return (id, record.species)
            }
            guard Set(pairs.map(\.0)).count == pairs.count else { throw CocoaError(.fileReadCorruptFile) }
            return Snapshot(birds: birds, byID: byID, byBirdNET: Dictionary(uniqueKeysWithValues: pairs),
                records: Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) }), metadata: metadata, error: nil)
        } catch {
            let fallback = DiscoverFixtures.catalog
            return Snapshot(birds: fallback, byID: Dictionary(uniqueKeysWithValues: fallback.map { ($0.id, $0) }),
                byBirdNET: [:], records: [:], metadata: nil,
                error: "De soortencatalogus kon niet worden geladen. Alleen de voorbeeldsoorten zijn beschikbaar.")
        }
    }()
    static var species: [Species] { snapshot.birds }
    static var metadata: SpeciesCatalogMetadata? { snapshot.metadata }
    static var loadError: String? { snapshot.error }
    static func species(id: String) -> Species? { snapshot.byID[id] }
    static func species(birdnetID: String) -> Species? { snapshot.byBirdNET[birdnetID] }
    static func record(id: String) -> WorldSpeciesRecord? { snapshot.records[id] }
    static var coverageNote: String {
        if let error = loadError { return error }
        let count = metadata?.checklistSpecies ?? species.count
        return "\(count.formatted(.number.locale(Locale(identifier: "nl_BE")))) soorten · AviList 2026. Illustraties en soortgegevens worden aangevuld."
    }
}

struct GuideSpeciesRepository: SpeciesRepository {
    var species: [Species] { SpeciesGuideCatalog.species }
    func search(_ query: String) -> [Species] { SpeciesCatalogSearch.results(for: query, in: species) }
}

enum BirdNETSpeciesLookup {
    static func species(id: String) -> Species? { SpeciesGuideCatalog.species(id: id) }
}
