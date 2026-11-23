import Foundation

// eBird's nearby endpoint is a species inventory, NOT a checklist-frequency feed.
// Documentation: https://documenter.getpostman.com/view/664302/S1ENwy59
// We keep the existing complete-checklist ranking available to other providers.
enum EBirdError: LocalizedError, Equatable {
    case invalidKey, rateLimited, unavailable, invalidResponse, invalidQuery, unsupportedDate, unknownSpecies

    var errorDescription: String? {
        switch self {
        case .invalidKey: "eBird herkent deze sleutel niet. Controleer je API-sleutel bij de instellingen."
        case .rateLimited: "eBird ontvangt te veel aanvragen. Probeer het over enkele minuten opnieuw."
        case .unavailable: "eBird is tijdelijk niet bereikbaar. Controleer je verbinding en probeer opnieuw."
        case .invalidResponse: "De vogelmeldingen konden niet worden gelezen. Probeer het later opnieuw."
        case .invalidQuery: "Deze locatie kan niet worden gebruikt. Kies een geldige locatie."
        case .unsupportedDate: "Lokale meldingen zijn alleen beschikbaar voor de huidige datum. Je kunt wel alle vogelsoorten doorzoeken."
        case .unknownSpecies: "De ontvangen soorten konden niet aan de vogelgids worden gekoppeld. Probeer het later opnieuw."
        }
    }
}

protocol EBirdHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct EBirdURLSessionClient: EBirdHTTPClient {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        session = URLSession(configuration: config)
    }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw EBirdError.invalidResponse }
        return (data, response)
    }
}

struct EBirdObservation: Decodable, Sendable {
    let speciesCode: String
    let sciName: String
    let obsDt: String
    let lat: Double
    let lng: Double
    let subId: String
    let obsValid: Bool
}

// Code first; scientific names/aliases only if unambiguous. No invented species
// or ID changes when a provider's taxonomy differs from our catalog.
struct EBirdSpeciesIndex: Sendable {
    private let codes: [String: Species]
    private let names: [String: Species]

    init(entries: [(code: String?, species: Species)]) {
        let codeGroups = Dictionary(grouping: entries.compactMap { entry -> (String, Species)? in
            guard let code = entry.code, !code.isEmpty else { return nil }
            return (code, entry.species)
        }, by: { $0.0 })
        codes = codeGroups.compactMapValues { group in
            Set(group.map { $0.1.id }).count == 1 ? group.first?.1 : nil
        }
        let namePairs = entries.flatMap { entry in
            ([entry.species.scientificName] + entry.species.aliases).map { ($0.lowercased(), entry.species) }
        }
        names = Dictionary(grouping: namePairs, by: { $0.0 }).compactMapValues { group in
            Set(group.map { $0.1.id }).count == 1 ? group.first?.1 : nil
        }
    }
    func species(code: String, scientificName: String) -> Species? {
        codes[code] ?? names[scientificName.lowercased()]
    }
    static let catalog = EBirdSpeciesIndex(entries: SpeciesGuideCatalog.species.map { bird in
        (code: SpeciesGuideCatalog.record(id: bird.id)?.ebirdCode, species: bird)
    })
}

struct EBirdDiscoverRepository: DiscoverRepository {
    private let keys: any EBirdKeyStore
    private let client: any EBirdHTTPClient
    private let index: @Sendable () -> EBirdSpeciesIndex
    private let now: @Sendable () -> Date

    init(keys: any EBirdKeyStore = EBirdKeychainStore(),
         client: any EBirdHTTPClient = EBirdURLSessionClient(),
         index: @escaping @Sendable () -> EBirdSpeciesIndex = { .catalog },
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.keys = keys
        self.client = client
        self.index = index
        self.now = now
    }

    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        guard let key = try keys.read(), !key.isEmpty else { throw DiscoverDataError.notConfigured }
        return try await reports(for: query, apiKey: key)
    }

    // Also used to validate a draft key before replacing a working stored key.
    func reports(for query: DiscoverQuery, apiKey: String) async throws -> DiscoverDataset {
        guard Calendar.current.isDate(query.now, inSameDayAs: now()) else { throw EBirdError.unsupportedDate }
        let request = try Self.request(query: query, apiKey: apiKey)
        let data: Data
        let response: HTTPURLResponse
        do { (data, response) = try await client.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch {
            if Task.isCancelled { throw CancellationError() }
            throw EBirdError.unavailable
        }
        try Task.checkCancellation()
        switch response.statusCode {
        case 200: break
        case 401, 403: throw EBirdError.invalidKey
        case 429: throw EBirdError.rateLimited
        default: throw EBirdError.unavailable
        }
        let observations: [EBirdObservation]
        do { observations = try JSONDecoder().decode([EBirdObservation].self, from: data) }
        catch { throw EBirdError.invalidResponse }
        // Never mistake an API cap for a complete local inventory.
        guard observations.count < 10_000 else { throw DiscoverDataError.incompleteFeed }
        let lookup = index()
        let reports = observations.compactMap { observation -> NearbyReport? in
            guard observation.obsValid,
                  let bird = lookup.species(code: observation.speciesCode, scientificName: observation.sciName),
                  let date = Self.observationDate(observation.obsDt, relativeTo: query.now) else { return nil }
            return NearbyReport(checklistID: observation.subId, species: bird, observedAt: date,
                                latitude: observation.lat, longitude: observation.lng, localObservedAt: observation.obsDt)
        }
        if !observations.isEmpty && reports.isEmpty { throw EBirdError.unknownSpecies }
        return DiscoverDataset(reports: reports, attribution: "eBird · laatst gemeld eerst",
                               isDemo: false, coversRequestedWindow: true, ordering: .providerRecency)
    }

    static func request(query: DiscoverQuery, apiKey: String) throws -> URLRequest {
        guard query.latitude.isFinite, query.longitude.isFinite,
              (-90...90).contains(query.latitude), (-180...180).contains(query.longitude),
              query.radiusKilometers.isFinite, (0...50).contains(query.radiusKilometers) else {
            throw EBirdError.invalidQuery
        }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.unicodeScalars.allSatisfy({ $0.isASCII && (33...126).contains($0.value) }) else {
            throw EBirdError.invalidKey
        }
        var components = URLComponents(string: "https://api.ebird.org/v2/data/obs/geo/recent")!
        // Keep the exact center so the local radius filter agrees with the server.
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(query.latitude)),
            URLQueryItem(name: "lng", value: String(query.longitude)),
            URLQueryItem(name: "dist", value: String(query.radiusKilometers)),
            URLQueryItem(name: "back", value: "30"),
            URLQueryItem(name: "sort", value: "date"),
            URLQueryItem(name: "cat", value: "species"),
            URLQueryItem(name: "includeProvisional", value: "false"),
            URLQueryItem(name: "maxResults", value: "10000")
        ]
        guard let url = components.url else { throw EBirdError.invalidQuery }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-eBirdApiToken")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    // obsDt is local wall-clock time without a timezone. Preserve eBird's
    // sort=date response order for recency, including ordering within a day;
    // interpret only its DATE locally for window validation.
    // Never invent a timezone or drop today's sightings while travelling.
    static func observationDate(_ value: String, relativeTo now: Date) -> Date? {
        let day = String(value.prefix(10))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard day.count == 10, let observedDay = formatter.date(from: day) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let difference = calendar.dateComponents([.day], from: observedDay, to: calendar.startOfDay(for: now)).day ?? 100
        guard (-1...30).contains(difference) else { return nil }
        return now.addingTimeInterval(-Double(max(0, difference)) * 86400)
    }
}

// Public Observation International endpoint, verified read-only on 23 Nov 2026.
// It returns public observations; no account, observer profile or media is imported.
// Provider civil times have no timezone. Compare them only within the same nearby
// area, retaining date-only records as date-only sort keys.
enum ObservationOrgError: LocalizedError {
    case unavailable, invalidResponse, incomplete
    var errorDescription: String? { "Observation.org is tijdelijk niet beschikbaar." }
}

struct ObservationOrgPage: Decodable, Sendable {
    let next: String?
    let results: [ObservationOrgRecord]
}

struct ObservationOrgRecord: Decodable, Sendable {
    struct Bird: Decodable, Sendable {
        let scientific_name: String
        let group: Int
        let type: String
    }
    struct Point: Decodable, Sendable { let coordinates: [Double] }
    let id: Int
    let date: String
    let time: String?
    let species_detail: Bird
    let point: Point?
    let is_certain: Bool
    let is_escape: Bool?
    let obscurity: Int?

    var url: URL? {
        guard id > 0 else { return nil }
        return URL(string: "https://observation.org/observation/\(id)/")
    }
}

private actor ObservationOrgCache {
    static let shared = ObservationOrgCache()
    private var entries: [String: (Date, DiscoverDataset)] = [:]
    func read(_ key: String) -> DiscoverDataset? {
        guard let value = entries[key], Date().timeIntervalSince(value.0) < 300 else { return nil }
        return value.1
    }
    func save(_ value: DiscoverDataset, key: String) {
        entries = entries.filter { Date().timeIntervalSince($0.value.0) < 300 }
        if entries.count >= 8 { entries.removeAll() }
        entries[key] = (Date(), value)
    }
}

struct ObservationOrgDiscoverRepository: DiscoverRepository {
    private let client: any EBirdHTTPClient
    private let index: @Sendable () -> EBirdSpeciesIndex
    private let cacheEnabled: Bool
    init(client: any EBirdHTTPClient = EBirdURLSessionClient(),
         index: @escaping @Sendable () -> EBirdSpeciesIndex = { .catalog }, cacheEnabled: Bool = true) {
        self.client = client
        self.index = index
        self.cacheEnabled = cacheEnabled
    }
    static func request(query: DiscoverQuery, daysBack: Int, offset: Int) throws -> URLRequest {
        guard query.latitude.isFinite, query.longitude.isFinite,
              (-90...90).contains(query.latitude), (-180...180).contains(query.longitude),
              query.radiusKilometers.isFinite, (1...50).contains(query.radiusKilometers),
              [0, 13, 26].contains(daysBack), offset >= 0 else { throw EBirdError.invalidQuery }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        var parts = URLComponents(string: "https://observation.org/api/v1/observations/around-point/")!
        parts.queryItems = [
            URLQueryItem(name: "coordinates", value: "\(query.latitude),\(query.longitude)"),
            URLQueryItem(name: "days", value: "14"),
            URLQueryItem(name: "end_date", value: formatter.string(from: query.now.addingTimeInterval(-Double(daysBack) * 86400))),
            URLQueryItem(name: "radius", value: String(Int(min(10, query.radiusKilometers) * 1000))),
            URLQueryItem(name: "species_group", value: "1"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        var request = URLRequest(url: parts.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("nl", forHTTPHeaderField: "Accept-Language")
        return request
    }
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        let key = "\(query.latitude),\(query.longitude),\(query.radiusKilometers),\(Int(query.now.timeIntervalSince1970 / 300))"
        if cacheEnabled, let cached = await ObservationOrgCache.shared.read(key) { return cached }
        let lookup = index()
        var seen = Set<Int>()
        var reports: [NearbyReport] = []
        var pages = 0
        // Overlap adjacent 14-day windows so midnight boundary inclusivity does
        // not lose a day. Ranking applies the exact requested 30-day window.
        for daysBack in [0, 13, 26] {
            var offset = 0
            while true {
                try Task.checkCancellation()
                pages += 1
                guard pages <= 30 else { throw ObservationOrgError.incomplete }
                let request = try Self.request(query: query, daysBack: daysBack, offset: offset)
                let (data, response) = try await client.data(for: request)
                guard response.statusCode == 200 else { throw ObservationOrgError.unavailable }
                let page: ObservationOrgPage
                do { page = try JSONDecoder().decode(ObservationOrgPage.self, from: data) }
                catch { throw ObservationOrgError.invalidResponse }
                for record in page.results where seen.insert(record.id).inserted {
                    guard record.is_certain, record.is_escape != true, (record.obscurity ?? 0) == 0,
                          record.species_detail.group == 1, record.species_detail.type == "S",
                          let point = record.point, point.coordinates.count == 2,
                          let bird = lookup.species(code: "", scientificName: record.species_detail.scientific_name),
                          let date = EBirdDiscoverRepository.observationDate(record.date, relativeTo: query.now),
                          let url = record.url else { continue }
                    reports.append(NearbyReport(checklistID: "observation:\(record.id)", species: bird,
                        observedAt: date, latitude: point.coordinates[1], longitude: point.coordinates[0],
                        observationURL: url, localObservedAt: record.date + " " + (record.time ?? "")))
                }
                guard page.next != nil else { break }
                // Never follow an untrusted pagination URL or loop on an empty page.
                guard !page.results.isEmpty else { throw ObservationOrgError.incomplete }
                offset += page.results.count
            }
        }
        try Task.checkCancellation()
        let dataset = DiscoverDataset(reports: reports, attribution: "Observation International", isDemo: false,
            coversRequestedWindow: true, ordering: .providerRecency,
            warning: query.radiusKilometers > 10 ? "Observation.org vult aan tot 10 km; eBird gebruikt je gekozen straal." : nil)
        if cacheEnabled { await ObservationOrgCache.shared.save(dataset, key: key) }
        return dataset
    }
}

struct CombinedDiscoverRepository: DiscoverRepository {
    let ebird: any DiscoverRepository
    let observation: any DiscoverRepository
    init(ebird: any DiscoverRepository = EBirdDiscoverRepository(),
         observation: any DiscoverRepository = ObservationOrgDiscoverRepository()) {
        self.ebird = ebird
        self.observation = observation
    }
    private func result(_ repository: any DiscoverRepository, query: DiscoverQuery) async -> Result<DiscoverDataset, Error> {
        do {
            let dataset = try await repository.reports(for: query)
            guard dataset.coversRequestedWindow else { throw DiscoverDataError.incompleteFeed }
            return .success(dataset)
        } catch { return .failure(error) }
    }
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        async let ebirdResult = result(ebird, query: query)
        async let observationResult = result(observation, query: query)
        let (first, second) = await (ebirdResult, observationResult)
        try Task.checkCancellation()
        return try Self.combine(ebird: first, observation: second)
    }
    static func combine(ebird: Result<DiscoverDataset, Error>,
                        observation: Result<DiscoverDataset, Error>) throws -> DiscoverDataset {
        var datasets: [DiscoverDataset] = []
        var warnings: [String] = []
        switch ebird {
        case .success(let data): datasets.append(data)
        case .failure(let error):
            if (error as? DiscoverDataError) == .notConfigured {
                warnings.append("Meldingen van Observation.org. Verbind eBird bij lokale vogelmeldingen om ook die bron toe te voegen.")
            } else { warnings.append("eBird is tijdelijk niet beschikbaar; alleen Observation.org wordt getoond.") }
        }
        switch observation {
        case .success(let data): datasets.append(data)
        case .failure: warnings.append("Observation.org is tijdelijk niet beschikbaar; alleen eBird wordt getoond.")
        }
        guard !datasets.isEmpty else {
            if case .failure(let error) = ebird { throw error }
            throw ObservationOrgError.unavailable
        }
        // Both feeds describe local civil time in the same nearby area. A date
        // without a time sorts at the start of that day, never with invented hour.
        let reports = datasets.flatMap(\.reports).enumerated().sorted { left, right in
            let a = left.element.localObservedAt ?? ""
            let b = right.element.localObservedAt ?? ""
            return a == b ? left.offset < right.offset : a > b
        }.map(\.element)
        warnings += datasets.compactMap(\.warning)
        return DiscoverDataset(reports: reports, attribution: datasets.map(\.attribution).joined(separator: " · "),
            isDemo: false, coversRequestedWindow: true, ordering: .providerRecency,
            warning: warnings.isEmpty ? nil : warnings.joined(separator: "\n"))
    }
}
