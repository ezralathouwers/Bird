import Foundation

struct BirdaImportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct BirdaImportBatch: Sendable {
    let observations: [Observation]
    let sessions: [BirdSession]
    var speciesCount: Int { Set(observations.map(\.speciesID)).count }
    var standaloneCount: Int { observations.filter { $0.sessionID == nil }.count }
}

struct BirdaImportPlan {
    let observations: [Observation]
    let sessions: [BirdSession]
    let addedObservations: Int
    let addedSessions: Int
    let skipped: Int
}

// Local-only import. Source UUIDs are persistent keys, never translated bird names.
enum BirdaImport {
    private static func key(_ value: String) -> String {
        value.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func decode(_ data: Data, catalog: [Species]) throws -> BirdaImportBatch {
        guard data.count <= 16 * 1024 * 1024, var text = String(data: data, encoding: .utf8) else {
            throw BirdaImportError(message: "Kies een UTF-8 CSV-export van Birda van maximaal 16 MB.")
        }
        if text.hasPrefix("\u{feff}") { text.removeFirst() }
        let rows = try CSV.parse(text)
        guard let header = rows.first, Set(header).count == header.count else {
            throw BirdaImportError(message: "De CSV heeft geen geldige, unieke kolomnamen.")
        }
        let required = ["sightingId", "date", "longitude", "latitude", "scientificName", "sessionId", "sessionTitle"]
        guard required.allSatisfy(header.contains), rows.count > 1, rows.count <= 100_001 else {
            throw BirdaImportError(message: "Dit is geen ondersteunde Birda-export, of het bestand bevat geen waarnemingen.")
        }
        var names: [String: Set<String>] = [:]
        let birds = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        for bird in catalog {
            for name in [bird.scientificName] + bird.aliases.flatMap({ $0.components(separatedBy: "|") }) {
                names[key(name), default: []].insert(bird.id)
            }
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let whole = ISO8601DateFormatter()
        let countryIndex = try? CountryBoundaryIndex.bundled.get()
        var observations: [Observation] = []
        var groups: [UUID: [Int]] = [:]
        var seen = Set<UUID>()
        for (offset, fields) in rows.dropFirst().enumerated() {
            func invalid(_ reason: String) -> BirdaImportError {
                BirdaImportError(message: "CSV-record \(offset + 2): \(reason) Er is niets geïmporteerd.")
            }
            guard fields.count == header.count else { throw invalid("Het aantal velden klopt niet.") }
            let row = Dictionary(uniqueKeysWithValues: zip(header, fields))
            func value(_ name: String) -> String { (row[name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let id = UUID(uuidString: value("sightingId")), seen.insert(id).inserted else {
                throw invalid("Ongeldige of dubbele waarnemings-ID.")
            }
            // Require an explicit offset: never interpret a source timestamp in the iPhone's timezone.
            let timestamp = value("date")
            guard timestamp.range(of: #"(Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression) != nil,
                  let date = fractional.date(from: timestamp) ?? whole.date(from: timestamp) else {
                throw invalid("De datum moet een geldige ISO-datum met tijdzone zijn.")
            }
            guard let latitude = Double(value("latitude")), let longitude = Double(value("longitude")),
                  latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else {
                throw invalid("Ongeldige coördinaten.")
            }
            let scientific = value("scientificName")
            guard !scientific.isEmpty, let matches = names[key(scientific)], matches.count == 1,
                  let speciesID = matches.first, let bird = birds[speciesID] else {
                throw invalid("De soort ‘\(scientific)’ is niet eenduidig gekoppeld aan de catalogus.")
            }
            var log = Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion,
                observedAt: date, locationName: coordinateName(latitude, longitude), count: 1,
                notes: row["note"] ?? "", status: .confirmed)
            log.id = id; log.createdAt = date; log.source = "birda-csv"
            log.latitude = latitude; log.longitude = longitude
            log.countryCode = ObservationCountry.normalized(countryIndex?.country(latitude: latitude, longitude: longitude))
            // Preserve all original fields, including source count, lifer and Birda taxonomy IDs.
            log.importMetadata = row
            observations.append(log)
            let sourceSession = value("sessionId")
            if !sourceSession.isEmpty {
                guard let sessionID = UUID(uuidString: sourceSession) else { throw invalid("Ongeldige sessie-ID.") }
                groups[sessionID, default: []].append(observations.count - 1)
            }
        }
        var sessions: [BirdSession] = []
        for (id, indices) in groups.sorted(by: { $0.key.uuidString < $1.key.uuidString }) where indices.count > 1 {
            let ordered = indices.sorted {
                observations[$0].observedAt == observations[$1].observedAt
                    ? observations[$0].id.uuidString < observations[$1].id.uuidString
                    : observations[$0].observedAt < observations[$1].observedAt
            }
            let first = observations[ordered[0]], last = observations[ordered[ordered.count - 1]]
            let titles = Set(indices.compactMap { observations[$0].importMetadata?["sessionTitle"] }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            guard titles.count <= 1 else { throw BirdaImportError(message: "Een Birda-sessie heeft meerdere titels. Er is niets geïmporteerd.") }
            var session = BirdSession(locationName: titles.first ?? first.locationName,
                latitude: first.latitude!, longitude: first.longitude!, countryCode: first.countryCode,
                startedAt: first.observedAt, endedAt: last.observedAt, isLive: false)
            session.id = id
            session.importMetadata = ["source": "birda-csv", "sessionId": id.uuidString,
                "sessionTitle": titles.first ?? "", "times": "first-last-observation", "count": "1"]
            sessions.append(session)
            for index in indices { observations[index].sessionID = id }
        }
        try ObservationStore.validateArchive(observations: observations, sessions: sessions)
        return BirdaImportBatch(observations: observations, sessions: sessions)
    }

    static func coordinateName(_ latitude: Double, _ longitude: Double) -> String {
        String(format: "%.5f, %.5f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude)
    }

    static func plan(_ batch: BirdaImportBatch, observations: [Observation], sessions: [BirdSession]) throws -> BirdaImportPlan {
        try ObservationStore.validateArchive(observations: batch.observations, sessions: batch.sessions)
        let oldLogs = Dictionary(uniqueKeysWithValues: observations.map { ($0.id, $0) })
        let oldSessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        for log in batch.observations where oldLogs[log.id] != nil {
            guard oldLogs[log.id]?.source == "birda-csv",
                  oldLogs[log.id]?.importMetadata?["sightingId"]?.lowercased() == log.id.uuidString.lowercased() else {
                throw BirdaImportError(message: "Een Birda-ID is al in gebruik door een andere waarneming. Je gegevens blijven ongewijzigd.")
            }
        }
        for session in batch.sessions where oldSessions[session.id] != nil {
            guard oldSessions[session.id]?.importMetadata?["source"] == "birda-csv" else {
                throw BirdaImportError(message: "Een Birda-ID is al in gebruik door een andere sessie. Je gegevens blijven ongewijzigd.")
            }
        }
        let addedLogs = batch.observations.filter { oldLogs[$0.id] == nil }
        let referencedSessions = Set(addedLogs.compactMap(\.sessionID))
        let addedSessions = batch.sessions.filter { oldSessions[$0.id] == nil && referencedSessions.contains($0.id) }
        let mergedLogs = observations + addedLogs, mergedSessions = sessions + addedSessions
        // Includes session bounds: do not silently replace edits to an existing imported session.
        try ObservationStore.validateArchive(observations: mergedLogs, sessions: mergedSessions)
        return BirdaImportPlan(observations: mergedLogs, sessions: mergedSessions,
            addedObservations: addedLogs.count, addedSessions: addedSessions.count,
            skipped: batch.observations.count - addedLogs.count)
    }

    private enum CSV {
        static func parse(_ text: String) throws -> [[String]] {
            // RFC 4180, including escaped quotes, quoted newlines and CRLF. Parse Unicode
            // scalars because Swift treats CRLF as a single Character.
            let input = Array(text.unicodeScalars)
            var rows: [[String]] = [], row: [String] = [], field = ""
            var quoted = false, closed = false, index = 0
            func malformed() -> BirdaImportError { BirdaImportError(message: "De CSV bevat ongeldige aanhalingstekens.") }
            func finishField() { row.append(field); field = ""; closed = false }
            func finishRow() {
                finishField()
                if row != [""] { rows.append(row) }
                row = []
            }
            while index < input.count {
                let scalar = input[index]
                if quoted {
                    if scalar == "\"" {
                        if index + 1 < input.count && input[index + 1] == "\"" { field.append("\""); index += 1 }
                        else { quoted = false; closed = true }
                    } else { field.unicodeScalars.append(scalar) }
                } else if scalar == "," { finishField() }
                else if scalar == "\r" || scalar == "\n" {
                    finishRow()
                    if scalar == "\r", index + 1 < input.count, input[index + 1] == "\n" { index += 1 }
                } else if scalar == "\"" {
                    guard field.isEmpty, !closed else { throw malformed() }
                    quoted = true
                } else {
                    guard !closed else { throw malformed() }
                    field.unicodeScalars.append(scalar)
                }
                index += 1
            }
            guard !quoted else { throw malformed() }
            if !row.isEmpty || !field.isEmpty || closed { finishRow() }
            return rows
        }
    }
}
