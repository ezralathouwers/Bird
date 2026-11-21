import Foundation
import CryptoKit

struct SpeciesWingspan: Codable, Sendable {
    let minimumCM: Double
    let maximumCM: Double
    let method: String
    let sourceScientificName: String
    let sourceURL: URL
    var isEstimated: Bool { ["estimated-wingspan-game", "estimated-fox-model"].contains(method) }
    var isValid: Bool {
        guard minimumCM.isFinite && maximumCM.isFinite && minimumCM > 0 && maximumCM >= minimumCM && maximumCM < 500 &&
            ["reported", "source-checked-guide", "source-reported-wikidata", "estimated-wingspan-game", "estimated-fox-model"].contains(method) && !sourceScientificName.isEmpty && sourceURL.scheme == "https" else { return false }
        if isEstimated {
            guard minimumCM == maximumCM else { return false }
            return method == "estimated-wingspan-game" ? sourceURL.absoluteString == "https://navarog.github.io/wingsearch/" :
                sourceURL.absoluteString == "https://doi.org/10.6084/m9.figshare.32089083.v1"
        }
        if method == "source-reported-wikidata" {
            return minimumCM == maximumCM && sourceURL.host == "www.wikidata.org" &&
                sourceURL.path.range(of: #"^/wiki/Q[0-9]+$"#, options: .regularExpression) != nil
        }
        return true
    }
    var displayValue: String {
        func number(_ value: Double) -> String {
            value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "nl_BE")))
        }
        let low = number(minimumCM), high = number(maximumCM)
        return (low == high ? low : "\(low)–\(high)") + " cm"
    }
}

struct SpeciesDetails: Codable, Sendable {
    let speciesID: String
    let scientificName: String
    let bio: String?
    let bioMethod: String?
    let bioSourceURLs: [URL]
    let wingspan: SpeciesWingspan?
    var isValid: Bool {
        guard !speciesID.isEmpty, !scientificName.isEmpty, wingspan?.isValid ?? true else { return false }
        if let bio {
            return !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bio.count <= 1000 &&
                ["wikipedia-nl-excerpt", "birdbase-habitat-diet", "source-summary-nl"].contains(bioMethod ?? "") &&
                !bioSourceURLs.isEmpty && bioSourceURLs.allSatisfy { $0.scheme == "https" }
        }
        return bioMethod == nil && bioSourceURLs.isEmpty
    }
    func addingFallbackWingspan(_ estimate: SpeciesWingspan?) -> SpeciesDetails {
        guard wingspan == nil, let estimate, estimate.isEstimated, estimate.isValid else { return self }
        return SpeciesDetails(speciesID: speciesID, scientificName: scientificName, bio: bio,
            bioMethod: bioMethod, bioSourceURLs: bioSourceURLs, wingspan: estimate)
    }
}

enum SpeciesDetailsError: Error { case invalidData }

enum SpeciesDetailsCatalog {
    private struct Provenance: Decodable { let records: Int; let sha256: String }
    private struct Snapshot: Sendable { let byID: [String: SpeciesDetails]; let error: String? }
    private static let snapshot: Snapshot = {
        do {
            guard let url = Bundle.main.url(forResource: "SpeciesDetails", withExtension: "json"),
                  let provenanceURL = Bundle.main.url(forResource: "SpeciesDetailsProvenance", withExtension: "json") else {
                throw SpeciesDetailsError.invalidData
            }
            let data = try Data(contentsOf: url)
            let provenance = try JSONDecoder().decode(Provenance.self, from: Data(contentsOf: provenanceURL))
            guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == provenance.sha256 else {
                throw SpeciesDetailsError.invalidData
            }
            let rows = try JSONDecoder().decode([SpeciesDetails].self, from: data)
            guard rows.count == provenance.records, Set(rows.map(\.speciesID)).count == rows.count,
                  rows.allSatisfy({ $0.isValid && $0.wingspan?.isEstimated != true && SpeciesGuideCatalog.species(id: $0.speciesID)?.scientificName == $0.scientificName }) else {
                throw SpeciesDetailsError.invalidData
            }
            return Snapshot(byID: Dictionary(uniqueKeysWithValues: rows.map { ($0.speciesID, $0) }), error: nil)
        } catch { return Snapshot(byID: [:], error: "De soortbeschrijvingen en spanwijdtes konden niet worden geladen.") }
    }()
    static var loadError: String? { snapshot.error }
    static func details(for speciesID: String) -> SpeciesDetails? {
        guard let details = snapshot.byID[speciesID] else { return nil }
        guard details.wingspan == nil else { return details }
        return details.addingFallbackWingspan(SpeciesWingspanEstimatesCatalog.wingspan(for: speciesID))
    }
}

// Estimated fallbacks have an independent hash/identity check. A damaged or
// missing estimate bundle must never invalidate reported facts or biographies.
enum SpeciesWingspanEstimatesCatalog {
    private struct Record: Decodable { let speciesID: String; let scientificName: String; let wingspan: SpeciesWingspan }
    private struct Provenance: Decodable { let records: Int; let sha256: String }
    private struct Snapshot: Sendable { let byID: [String: SpeciesWingspan]; let error: String? }
    private static let snapshot: Snapshot = {
        do {
            guard let url = Bundle.main.url(forResource: "SpeciesWingspanEstimates", withExtension: "json"),
                  let provenanceURL = Bundle.main.url(forResource: "SpeciesWingspanEstimatesProvenance", withExtension: "json") else {
                throw SpeciesDetailsError.invalidData
            }
            let data = try Data(contentsOf: url)
            let provenance = try JSONDecoder().decode(Provenance.self, from: Data(contentsOf: provenanceURL))
            guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == provenance.sha256 else {
                throw SpeciesDetailsError.invalidData
            }
            let rows = try JSONDecoder().decode([Record].self, from: data)
            guard rows.count == provenance.records, Set(rows.map(\.speciesID)).count == rows.count,
                  rows.allSatisfy({ $0.wingspan.isValid && $0.wingspan.isEstimated && SpeciesGuideCatalog.species(id: $0.speciesID)?.scientificName == $0.scientificName }) else {
                throw SpeciesDetailsError.invalidData
            }
            return Snapshot(byID: Dictionary(uniqueKeysWithValues: rows.map { ($0.speciesID, $0.wingspan) }), error: nil)
        } catch {
            return Snapshot(byID: [:], error: "De geschatte spanwijdtes konden niet worden geladen.")
        }
    }()
    static var loadError: String? { snapshot.error }
    static func wingspan(for speciesID: String) -> SpeciesWingspan? { snapshot.byID[speciesID] }
}
