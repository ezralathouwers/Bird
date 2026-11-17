import XCTest
@testable import BirdingCompanion

@MainActor
final class Phase1Tests: XCTestCase {
    private func record(status: IdentificationStatus = .confirmed, captive: Bool = false) -> Observation {
        var record = Observation(speciesID: MockSpeciesRepository.kingfisher.id,
            taxonomyVersion: MockSpeciesRepository.kingfisher.taxonomyVersion,
            observedAt: Date(timeIntervalSince1970: 1000), locationName: "Testlocatie",
            count: 1, notes: "Test", status: status)
        record.isCaptive = captive
        return record
    }
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("observations.json")
    }
    func testLoggedBadgeUsesPersistedSpeciesRecords() throws {
        let store = ObservationStore(persistence: PreviewObservationPersistence())
        let bird = MockSpeciesRepository.kingfisher
        XCTAssertEqual(store.logStatus(for: bird.id), .notLogged)
        try store.save(record(status: .uncertain))
        XCTAssertEqual(store.logStatus(for: bird.id), .logged)
        XCTAssertEqual(store.logStatus(for: "another-species"), .notLogged)
    }

    func testSpeciesHistoryFiltersAndSortsNewestFirstWithoutDroppingUncertainRecords() throws {
        let store = ObservationStore(persistence: PreviewObservationPersistence())
        var earlier = record()
        earlier.observedAt = Date(timeIntervalSince1970: 100)
        var later = record(status: .uncertain)
        later.observedAt = Date(timeIntervalSince1970: 200)
        let otherSpecies = Observation(speciesID: "other-species", taxonomyVersion: "mock-v1",
            observedAt: Date(timeIntervalSince1970: 300), locationName: "", count: 1, notes: "", status: .confirmed)
        try store.save(later)
        try store.save(otherSpecies)
        try store.save(earlier)
        XCTAssertEqual(store.observations(for: earlier.speciesID).map(\.id), [later.id, earlier.id])
        XCTAssertTrue(store.observations(for: "unseen-species").isEmpty)
    }

    func testLegacyObservationDecodesWithoutCoordinates() throws {
        let old = record(status: .uncertain, captive: true)
        let data = try JSONEncoder().encode(old)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "latitude")
        json.removeValue(forKey: "longitude")
        let restored = try JSONDecoder().decode(Observation.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.latitude)
        XCTAssertNil(restored.longitude)
        XCTAssertNil(restored.countryCode)
        XCTAssertEqual(restored.status, .uncertain)
        XCTAssertTrue(restored.isCaptive)
        XCTAssertEqual(restored.count, old.count)
    }

    func testCoordinatesValidateAndRoundTrip() throws {
        var observation = record()
        observation.latitude = 0.5
        observation.longitude = 1.5
        try observation.validate()
        XCTAssertEqual(try JSONDecoder().decode(Observation.self, from: JSONEncoder().encode(observation)), observation)
        observation.longitude = nil
        XCTAssertThrowsError(try observation.validate())
        observation.longitude = 181
        XCTAssertThrowsError(try observation.validate())
        observation.longitude = 1.5
        observation.latitude = .nan
        XCTAssertThrowsError(try observation.validate())
    }

    func testCountryFlagsOnlyForKnownForeignCountries() throws {
        XCTAssertNil(ObservationCountry.foreignFlag(for: nil))
        XCTAssertNil(ObservationCountry.foreignFlag(for: "BE"))
        XCTAssertNil(ObservationCountry.foreignFlag(for: " be "))
        XCTAssertNil(ObservationCountry.foreignFlag(for: "ZZ"))
        XCTAssertEqual(ObservationCountry.foreignFlag(for: " nl "), "🇳🇱")
        XCTAssertEqual(ObservationCountry.foreignFlag(for: "FR"), "🇫🇷")
        var observation = record()
        observation.countryCode = "NL"
        let decoded = try JSONDecoder().decode(Observation.self, from: JSONEncoder().encode(observation))
        XCTAssertEqual(decoded.countryCode, "NL")
    }

    func testSearchByDutchEnglishAndScientificName() {
        let repository = MockSpeciesRepository()
        for query in ["ijsvogel", "KINGFISHER", "Alcedo", " ijsvogel "] {
            XCTAssertEqual(repository.search(query).map(\.id), [MockSpeciesRepository.kingfisher.id])
        }
        XCTAssertTrue(repository.search("onbekend").isEmpty)
    }
    func testSaveReloadAndEditPreservesIdentity() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let persistence = JSONObservationPersistence(url: url)
        let store = ObservationStore(persistence: persistence)
        var observation = record()
        try store.save(observation)
        XCTAssertThrowsError(try store.save(observation))
        observation.count = 3
        try store.save(observation, editing: true)
        let reloaded = ObservationStore(persistence: persistence)
        XCTAssertNil(reloaded.loadError)
        XCTAssertEqual(reloaded.observations, [observation])
        XCTAssertEqual(reloaded.logStatus(for: observation.speciesID), .logged)
        let exported = try JSONDecoder().decode([Observation].self, from: reloaded.exportData())
        XCTAssertEqual(exported, [observation])
    }
    func testLifelistDeduplicatesAndExcludesUncertainAndCaptive() {
        let records = [record(), record(), record(status: .uncertain), record(captive: true)]
        XCTAssertEqual(LifelistRules().speciesIDs(in: records).count, 1)
        XCTAssertTrue(LifelistRules().speciesIDs(in: [record(status: .uncertain), record(captive: true)]).isEmpty)
        XCTAssertEqual(LifelistRules(includeCaptive: true).speciesIDs(in: [record(captive: true)]).count, 1)
    }
    func testInvalidCountAndMissingEditAreRejected() throws {
        let store = ObservationStore(persistence: PreviewObservationPersistence())
        var invalid = record()
        invalid.count = 0
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertThrowsError(try store.save(record(), editing: true))
        XCTAssertTrue(store.observations.isEmpty)
    }
    func testCorruptionIsPreservedAndWritesBlocked() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: url)
        let store = ObservationStore(persistence: JSONObservationPersistence(url: url))
        XCTAssertNotNil(store.loadError)
        XCTAssertEqual(store.logStatus(for: MockSpeciesRepository.kingfisher.id), .unavailable)
        XCTAssertThrowsError(try store.save(record()))
        XCTAssertThrowsError(try store.exportData())
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }
    func testFailedWriteDoesNotPublishUnsavedObservation() {
        let store = ObservationStore(persistence: FailingPersistence())
        XCTAssertThrowsError(try store.save(record()))
        XCTAssertTrue(store.observations.isEmpty)
    }
}

private struct FailingPersistence: ObservationPersistence {
    func load() throws -> [Observation] { [] }
    func save(_ observations: [Observation]) throws { throw CocoaError(.fileWriteNoPermission) }
}

final class SpeciesRangeTests: XCTestCase {
    // Fictional square, intentionally unrelated to kingfisher distribution.
    private let fixture = """
    {"type":"FeatureCollection","source":"Unit test fixture","license":"Project test data","version":"test-v1",
    "features":[{"type":"Feature","properties":{},"geometry":{"type":"Polygon",
    "coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]]]}}]}
    """

    func testPolygonAndProvenanceDecode() throws {
        let dataset = try BundledSpeciesRangeRepository.decode(Data(fixture.utf8))
        XCTAssertEqual(dataset.polygons.count, 1)
        XCTAssertEqual(dataset.polygons[0].pointCount, 5)
        XCTAssertEqual(dataset.version, "test-v1")
        XCTAssertTrue(dataset.attribution.contains("Unit test fixture"))
    }

    func testMissingLicenseAndEmptyGeometryAreRejected() {
        let missingLicense = fixture.replacingOccurrences(of: "\"license\":\"Project test data\",", with: "")
        XCTAssertThrowsError(try BundledSpeciesRangeRepository.decode(Data(missingLicense.utf8)))
        let empty = """
        {"type":"FeatureCollection","source":"Test","license":"Test","version":"1","features":[]}
        """
        XCTAssertThrowsError(try BundledSpeciesRangeRepository.decode(Data(empty.utf8)))
    }

    func testMissingBundledRangeIsExplicitlyUnavailable() {
        XCTAssertThrowsError(try BundledSpeciesRangeRepository().load(speciesID: "missing-test-species")) {
            guard case RangeDataError.unavailable = $0 else {
                return XCTFail("Expected explicit unavailable data state")
            }
        }
    }
}

@MainActor
final class ObservationLocationTests: XCTestCase {
    func testPlaceNamePrefersNatureAreaThenTown() {
        XCTAssertEqual(PlaceNameSuggestion.preferred(area: "Park", locality: "Stad", name: "Straat", region: "Regio"), "Park")
        XCTAssertEqual(PlaceNameSuggestion.preferred(area: "  ", locality: "Stad", name: "Straat", region: nil), "Stad")
    }

    func testRequiredLocationAndAutomaticCountry() async {
        let model = ObservationLocationModel(namingService: TestPlaceNamingService())
        XCTAssertFalse(model.canSave)
        await model.select(latitude: 0.5, longitude: 1.5)?.value
        XCTAssertEqual(model.locationName, "Voorbeeldpark")
        XCTAssertEqual(model.countryCode, "NL")
        XCTAssertTrue(model.canSave)
    }

    func testManualNameSurvivesLateSuggestionAndLatestPointWins() async {
        let model = ObservationLocationModel(namingService: TestPlaceNamingService())
        let older = model.select(latitude: 1, longitude: 2)
        let latest = model.select(latitude: 3, longitude: 4)
        model.editName("Mijn plek")
        await older?.value
        await latest?.value
        XCTAssertEqual(model.latitude, 3)
        XCTAssertEqual(model.longitude, 4)
        XCTAssertEqual(model.locationName, "Mijn plek")
        XCTAssertEqual(model.countryCode, "NL")
    }

    func testNameLookupFailureAllowsManualOfflineFallback() async {
        let model = ObservationLocationModel(namingService: TestPlaceNamingService(fails: true))
        await model.select(latitude: 1, longitude: 2)?.value
        XCTAssertNotNil(model.message)
        XCTAssertFalse(model.canSave)
        model.editName("Handmatig ingevoerde plek")
        XCTAssertTrue(model.canSave)
        XCTAssertNil(model.countryCode)
    }
}

@MainActor
private struct TestPlaceNamingService: PlaceNamingService {
    var fails = false
    func suggestion(latitude: Double, longitude: Double) async throws -> PlaceSuggestion {
        if fails { throw CocoaError(.fileReadUnknown) }
        return PlaceSuggestion(name: "Voorbeeldpark", countryCode: "nl")
    }
}

final class DiscoverRankingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private var query: DiscoverQuery { DiscoverQuery(latitude: 0, longitude: 0, now: now, radiusKilometers: 25) }
    private var first: Species { DiscoverFixtures.catalog[0] }
    private var second: Species { DiscoverFixtures.catalog[1] }
    private func report(_ bird: Species, checklist: String, daysAgo: Double = 1, latitude: Double = 0) -> NearbyReport {
        NearbyReport(checklistID: checklist, species: bird, observedAt: now.addingTimeInterval(-daysAgo * 86400),
                     latitude: latitude, longitude: 0)
    }

    func testRankingCountsDistinctChecklistsWithinAreaAndThirtyDays() {
        let reports = [report(first, checklist: "A"), report(first, checklist: "A"),
            report(first, checklist: "B"), report(second, checklist: "C"),
            report(second, checklist: "old", daysAgo: 31), report(second, checklist: "future", daysAgo: -1),
            report(second, checklist: "far", latitude: 10), report(second, checklist: "")]
        let ranked = DiscoverRanking.ranked(reports, query: query)
        XCTAssertEqual(ranked.map(\.id), [first.id, second.id])
        XCTAssertEqual(ranked.map(\.reportCount), [2, 1])
    }

    func testBoundaryAndTieOrderAreDeterministic() {
        let ranked = DiscoverRanking.ranked([report(first, checklist: "A", daysAgo: 30),
                                            report(second, checklist: "B", daysAgo: 0)], query: query)
        XCTAssertEqual(ranked.map(\.species.dutchName), ["Koolmees", "Merel"])
    }

    func testLoggedFiltersUseStableIDsAndPreserveRanking() {
        let ranked = DiscoverRanking.ranked([report(first, checklist: "A"), report(second, checklist: "B")], query: query)
        let record = Observation(speciesID: first.id, taxonomyVersion: first.taxonomyVersion,
            observedAt: now, locationName: "Fictional fixture", count: 1, notes: "", status: .confirmed)
        XCTAssertEqual(DiscoverRanking.filtered(ranked, filter: .logged, observations: [record]).map(\.id), [first.id])
        XCTAssertEqual(DiscoverRanking.filtered(ranked, filter: .notLogged, observations: [record]).map(\.id), [second.id])
        XCTAssertTrue(DiscoverRanking.filtered(ranked, filter: .notLogged, observations: [], statusAvailable: false).isEmpty)
        XCTAssertEqual(DiscoverRanking.filtered(ranked, filter: .all, observations: []).count, 2)
    }
}

@MainActor
final class DiscoverViewModelTests: XCTestCase {
    func testIncompleteProviderCannotProduceMisleadingFrequencyRanking() async {
        let model = DiscoverViewModel(repository: IncompleteDiscoverFixture())
        await model.load(query: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: 25))
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertNotNil(model.message)
        XCTAssertNil(model.loadedQuery)
    }

    func testDemoIsExplicitAndMissingProviderDoesNotInventLiveRows() async {
        let model = DiscoverViewModel()
        let query = DiscoverQuery(latitude: 0, longitude: 0,
            now: Date(timeIntervalSince1970: 2_000_000_000), radiusKilometers: 25)
        await model.load(query: query, demo: true)
        XCTAssertTrue(model.isDemo)
        XCTAssertEqual(model.rows.count, 6)
        XCTAssertEqual(model.rows.map(\.reportCount), [12, 10, 8, 6, 4, 2])
        await model.load(query: query)
        XCTAssertFalse(model.isDemo)
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertNotNil(model.message)
        XCTAssertNil(model.loadedQuery)
    }
}

private struct IncompleteDiscoverFixture: DiscoverRepository {
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        DiscoverDataset(reports: [], attribution: "Incomplete test feed", isDemo: false, coversRequestedWindow: false)
    }
}

final class LogbookProjectionTests: XCTestCase {
    private var catalog: [Species] { DiscoverFixtures.catalog }
    private func record(_ species: Species, created: Double, observed: Double = 0) -> Observation {
        var value = Observation(speciesID: species.id, taxonomyVersion: species.taxonomyVersion,
            observedAt: Date(timeIntervalSince1970: observed), locationName: "Testplek", count: 1,
            notes: "", status: .confirmed)
        value.createdAt = Date(timeIntervalSince1970: created)
        return value
    }

    func testSpeciesAreUniqueAndUnloggedSpeciesAreAbsent() {
        let bird = catalog[0]
        let rows = LogbookProjection.species(observations: [record(bird, created: 1), record(bird, created: 2)],
            catalog: catalog, sort: .family)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.id, bird.id)
        XCTAssertEqual(rows.first?.lastLoggedAt, Date(timeIntervalSince1970: 2))
    }

    func testTwoTitSpeciesShareOneFamilyAndRowsAreAlphabetical() {
        let greatTit = catalog.first { $0.scientificName == "Parus major" }!
        let blueTit = catalog.first { $0.scientificName == "Cyanistes caeruleus" }!
        let rows = LogbookProjection.species(observations: [record(blueTit, created: 2), record(greatTit, created: 1)],
            catalog: catalog, sort: .family)
        let groups = LogbookProjection.families(from: rows)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.family.id, "Paridae")
        XCTAssertEqual(groups.first?.species.map(\.species.dutchName), ["Koolmees", "Pimpelmees"])
    }

    func testRecentOrderUsesCreationTimeAndDoesNotGroup() {
        let olderLog = record(catalog[0], created: 10, observed: 500)
        let newerLog = record(catalog[1], created: 20, observed: 1)
        let rows = LogbookProjection.species(observations: [olderLog, newerLog], catalog: catalog, sort: .lastLogged)
        XCTAssertEqual(rows.map(\.id), [catalog[1].id, catalog[0].id])
    }

    func testUnknownSpeciesRemainsVisibleAndUnknownFamilySortsLast() {
        let unknown = Species(id: "unmapped-species", taxonomyVersion: "legacy-v1",
            dutchName: "Test", englishName: "Test", scientificName: "")
        let rows = LogbookProjection.species(observations: [record(unknown, created: 2), record(catalog[0], created: 1)],
            catalog: catalog, sort: .family)
        XCTAssertEqual(rows.count, 2)
        let groups = LogbookProjection.families(from: rows)
        XCTAssertEqual(groups.last?.family, BirdFamily.unknown)
        XCTAssertEqual(groups.last?.species.first?.id, "unmapped-species")
    }

    func testEmptyAndTiedRecentOrderAreStable() {
        XCTAssertTrue(LogbookProjection.species(observations: [], catalog: catalog, sort: .family).isEmpty)
        let rows = LogbookProjection.species(observations: [record(catalog[0], created: 1), record(catalog[1], created: 1)],
            catalog: catalog, sort: .lastLogged)
        XCTAssertEqual(rows.map(\.species.dutchName), ["Koolmees", "Merel"])
    }
}
