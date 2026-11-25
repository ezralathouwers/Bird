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
    var sessionID: UUID? = nil
    var importMetadata: [String: String]? = nil
    var timeZoneIdentifier: String? = nil

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


struct BirdSession: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var locationName: String
    var latitude: Double
    var longitude: Double
    var countryCode: String?
    var startedAt: Date
    var endedAt: Date?
    var isLive: Bool
    var importMetadata: [String: String]? = nil
    var timeZoneIdentifier: String? = nil
    var habitatSceneID: String? = nil

    func validate() throws {
        guard !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude),
              startedAt.timeIntervalSince1970.isFinite,
              endedAt.map({ $0.timeIntervalSince1970.isFinite && $0 >= startedAt }) ?? isLive else {
            throw SessionError.invalidSession
        }
    }
}

enum SessionError: LocalizedError {
    case invalidSession, alreadyActive, noActiveSession, invalidLog, duplicateSpecies, unsupportedPersistence, reviewChanged
    var errorDescription: String? {
        switch self {
        case .invalidSession: "Kies een locatie en een geldige begin- en eindtijd."
        case .alreadyActive: "Er loopt al een livesessie. Rond die eerst af."
        case .noActiveSession: "Deze livesessie is niet meer actief."
        case .duplicateSpecies: "Deze soort is al toegevoegd aan de livesessie."
        case .invalidLog: "De waarneming moet binnen de sessie vallen en een geldige locatie hebben."
        case .reviewChanged: "De sessie is ondertussen gewijzigd. Open het afrondscherm opnieuw om alle waarnemingen te controleren."
        case .unsupportedPersistence: "Deze opslag ondersteunt nog geen sessies."
        }
    }
}

struct BirdingArchive: Codable, Equatable, Sendable {
    var version = 3
    var observations: [Observation]
    var sessions: [BirdSession]
    var goals: [BirdGoal]? = nil
    var appliedDataFixes: [String]? = nil
}

struct SessionLogLocation: Sendable {
    let latitude: Double
    let longitude: Double
    let name: String
    let countryCode: String?
}

// A source timestamp is an absolute instant. Unknown source zones must never
// silently become the current device zone, especially for historical travel.
enum HistoryTime {
    static func zone(identifier: String?, imported: Bool) -> TimeZone {
        identifier.flatMap(TimeZone.init(identifier:)) ?? (imported ? TimeZone(secondsFromGMT: 0)! : .current)
    }
    static func text(_ date: Date, identifier: String?, imported: Bool,
                     day: Date.FormatStyle.DateStyle = .abbreviated,
                     time: Date.FormatStyle.TimeStyle = .shortened) -> String {
        var style = Date.FormatStyle(date: day, time: time, locale: Locale(identifier: "nl_BE"))
        style.timeZone = zone(identifier: identifier, imported: imported)
        // Presentation only: keep the source/UTC fallback zone and stored instant.
        return date.formatted(style)
    }
}

extension Observation {
    var historyTimeZone: TimeZone { HistoryTime.zone(identifier: timeZoneIdentifier, imported: source == "birda-csv") }
    func historyDate(day: Date.FormatStyle.DateStyle = .abbreviated, time: Date.FormatStyle.TimeStyle = .shortened) -> String {
        HistoryTime.text(observedAt, identifier: timeZoneIdentifier, imported: source == "birda-csv", day: day, time: time)
    }
}

extension BirdSession {
    var historyTimeZone: TimeZone { HistoryTime.zone(identifier: timeZoneIdentifier, imported: importMetadata?["source"] == "birda-csv") }
    func historyDate(_ date: Date, day: Date.FormatStyle.DateStyle = .abbreviated,
                     time: Date.FormatStyle.TimeStyle = .shortened) -> String {
        HistoryTime.text(date, identifier: timeZoneIdentifier, imported: importMetadata?["source"] == "birda-csv", day: day, time: time)
    }
}
