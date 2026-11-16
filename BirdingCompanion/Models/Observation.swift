import Foundation

enum IdentificationStatus: String, Codable, CaseIterable {
    case confirmed, uncertain
}

struct Observation: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    let speciesID: String
    let taxonomyVersion: String
    var observedAt: Date
    var createdAt = Date()
    var locationName: String
    var count: Int
    var notes: String
    var status: IdentificationStatus
    var isCaptive = false
    var source = "personal-manual"
    var latitude: Double? = nil
    var longitude: Double? = nil
    var countryCode: String? = nil

    func validate() throws {
        guard !speciesID.isEmpty, !taxonomyVersion.isEmpty, count > 0 else {
            throw ObservationError.invalidRecord
        }
        switch (latitude, longitude) {
        case (nil, nil): break
        case let (.some(latitude), .some(longitude)):
            guard latitude.isFinite, longitude.isFinite,
                  (-90...90).contains(latitude), (-180...180).contains(longitude) else {
                throw ObservationError.invalidRecord
            }
        default: throw ObservationError.invalidRecord
        }
    }
}

enum ObservationError: LocalizedError {
    case invalidRecord, duplicateID, missingRecord
    var errorDescription: String? {
        switch self {
        case .invalidRecord: "Vul een geldige soort en een aantal groter dan nul in."
        case .duplicateID: "Deze waarneming bestaat al."
        case .missingRecord: "Deze waarneming is niet meer beschikbaar."
        }
    }
}

struct LifelistRules {
    var includeCaptive = false
    func speciesIDs(in observations: [Observation]) -> Set<String> {
        Set(observations.filter {
            $0.status == .confirmed && (includeCaptive || !$0.isCaptive)
        }.map(\.speciesID))
    }
}

struct ObservationCountry {
    static let codes = Locale.Region.isoRegions.map(\.identifier).filter { code in
        code.utf8.count == 2 && code.utf8.allSatisfy { (65...90).contains($0) }
    }

    static func normalized(_ value: String?) -> String? {
        guard let code = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              codes.contains(code) else { return nil }
        return code
    }

    static func name(for code: String) -> String {
        Locale(identifier: "nl_BE").localizedString(forRegionCode: code) ?? code
    }

    static func foreignFlag(for value: String?) -> String? {
        guard let code = normalized(value), code != "BE" else { return nil }
        return String(String.UnicodeScalarView(code.unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }))
    }
}
