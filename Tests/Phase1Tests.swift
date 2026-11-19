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
        XCTAssertEqual(rows.first?.firstObservedAt, Date(timeIntervalSince1970: 0))
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

    func testDiscoveryOrderUsesFirstObservedDateAndIgnoresRepeatSightings() {
        let firstOldSpecies = record(catalog[0], created: 1000, observed: 10)
        let repeatOldSpecies = record(catalog[0], created: 3000, observed: 900)
        let firstNewSpecies = record(catalog[1], created: 500, observed: 20)
        let records = [repeatOldSpecies, firstNewSpecies, firstOldSpecies]
        for input in [records, Array(records.reversed())] {
            let rows = LogbookProjection.species(observations: input, catalog: catalog, sort: .lastLogged)
            XCTAssertEqual(rows.map(\.id), [catalog[1].id, catalog[0].id])
            XCTAssertEqual(rows.last?.firstObservedAt, Date(timeIntervalSince1970: 10))
        }
    }

    func testBackdatedFirstSightingReordersDiscoveryList() {
        let initial = [record(catalog[0], created: 100, observed: 20),
                       record(catalog[1], created: 200, observed: 10)]
        let backdated = record(catalog[0], created: 300, observed: 1)
        let rows = LogbookProjection.species(observations: initial + [backdated], catalog: catalog, sort: .lastLogged)
        XCTAssertEqual(rows.map(\.id), [catalog[1].id, catalog[0].id])
        XCTAssertEqual(LogbookSort.lastLogged.label, "Laatst ontdekt")
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

@MainActor
final class SessionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1000)
    private func session(live: Bool) -> BirdSession {
        BirdSession(locationName: "Testgebied", latitude: 51, longitude: 4, countryCode: "BE",
            startedAt: start, endedAt: live ? nil : start.addingTimeInterval(600), isLive: live)
    }
    private func url() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }

    func testCompletedSessionWritesIndividualLogsAtomicallyAndReloads() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let completed = session(live: false)
        let bird = DiscoverFixtures.catalog[0]
        try store.addCompletedSession(completed, species: [bird, bird, DiscoverFixtures.catalog[1]])
        XCTAssertEqual(store.observations.count, 2)
        XCTAssertTrue(store.observations.allSatisfy { $0.sessionID == completed.id && $0.observedAt == start && $0.latitude == 51 })
        XCTAssertEqual(store.logStatus(for: bird.id), .logged)
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertNil(restored.loadError)
        XCTAssertEqual(restored.sessions, [completed])
        XCTAssertEqual(restored.observations, store.observations)
        let exported = try JSONDecoder().decode(BirdingArchive.self, from: restored.exportArchiveData())
        XCTAssertEqual(exported.sessions, [completed])
    }

    func testActiveSessionSurvivesRestartAndLiveLogsKeepOwnTimeAndLocation() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let persistence = JSONObservationPersistence(url: path)
        let store = ObservationStore(persistence: persistence)
        let live = session(live: true)
        try store.startSession(live)
        XCTAssertThrowsError(try store.startSession(session(live: true)))
        let restored = ObservationStore(persistence: persistence)
        XCTAssertEqual(restored.activeSession?.id, live.id)
        let point = SessionLogLocation(latitude: 52, longitude: 5, name: "Andere plek", countryCode: "NL")
        try restored.logLive(DiscoverFixtures.catalog[0], sessionID: live.id, at: start.addingTimeInterval(100), location: point)
        try restored.logLive(DiscoverFixtures.catalog[0], sessionID: live.id, at: start.addingTimeInterval(200), location: point)
        XCTAssertEqual(restored.observations.count, 2)
        XCTAssertEqual(restored.observations.first?.latitude, 52)
        XCTAssertEqual(restored.observations.first?.observedAt, start.addingTimeInterval(100))
        XCTAssertThrowsError(try restored.finishSession(at: start.addingTimeInterval(50)))
        XCTAssertNotNil(restored.activeSession)
        try restored.finishSession(at: start.addingTimeInterval(300))
        XCTAssertNil(restored.activeSession)
        XCTAssertThrowsError(try restored.logLive(DiscoverFixtures.catalog[0], sessionID: live.id, at: start.addingTimeInterval(400), location: point))
    }

    func testLegacyArrayMigrationPreservesRecords() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let bird = DiscoverFixtures.catalog[0]
        let log = Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion,
            observedAt: start, locationName: "Oud", count: 1, notes: "Bewaard", status: .confirmed)
        try JSONEncoder().encode([log]).write(to: path)
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertEqual(store.observations, [log])
        try store.startSession(session(live: true))
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertEqual(restored.observations, [log])
        XCTAssertNotNil(restored.activeSession)
    }

    func testSessionWriteFailurePublishesNeitherSessionsNorLogs() {
        let store = ObservationStore(persistence: FailingSessionPersistence())
        XCTAssertThrowsError(try store.addCompletedSession(session(live: false), species: DiscoverFixtures.catalog))
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.observations.isEmpty)
    }

    func testCompletedSessionsAreNewestFirstAndLiveSessionIsExcluded() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let first = session(live: false)
        var second = session(live: false)
        second.startedAt = start.addingTimeInterval(1000)
        second.endedAt = start.addingTimeInterval(1500)
        try store.addCompletedSession(first, species: [])
        try store.addCompletedSession(second, species: [])
        try store.startSession(session(live: true))
        XCTAssertEqual(store.completedSessions.map(\.id), [second.id, first.id])
    }

    func testFailedLiveWritePreservesActiveSessionAndExistingLogs() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let persistence = JSONObservationPersistence(url: path)
        let live = session(live: true)
        try persistence.save([], sessions: [live])
        // A loaded active session whose storage rejects every subsequent write.
        let store = ObservationStore(persistence: ReadOnlySessionPersistence(session: live))
        let point = SessionLogLocation(latitude: 51, longitude: 4, name: "Testplek", countryCode: "BE")
        XCTAssertThrowsError(try store.logLive(DiscoverFixtures.catalog[0], sessionID: live.id,
            at: start.addingTimeInterval(10), location: point))
        XCTAssertThrowsError(try store.finishSession(at: start.addingTimeInterval(20)))
        XCTAssertEqual(store.activeSession, live)
        XCTAssertTrue(store.observations.isEmpty)
    }

    func testFinishReviewPreservesLiveCoordinatesAndOtherObservations() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let live = session(live: true)
        try store.startSession(live)
        let point = SessionLogLocation(latitude: 52, longitude: 5, name: "Live plek", countryCode: "NL")
        try store.logLive(DiscoverFixtures.catalog[0], sessionID: live.id, at: start.addingTimeInterval(100), location: point)
        let standalone = Observation(speciesID: "other", taxonomyVersion: "test", observedAt: start,
            locationName: "Los", count: 1, notes: "Bewaren", status: .confirmed)
        try store.save(standalone)
        let original = store.observations(in: live)
        var review = live; review.locationName = "Nieuwe sessienaam"; review.endedAt = start.addingTimeInterval(300)
        var revised = original; revised[0].observedAt = start.addingTimeInterval(110)
        try store.completeSession(review, logs: revised, expectedLogs: original)
        XCTAssertNil(store.activeSession)
        XCTAssertEqual(store.completedSessions.first?.locationName, "Nieuwe sessienaam")
        XCTAssertEqual(store.observations(in: review).first?.latitude, 52)
        XCTAssertEqual(store.observations(in: review).first?.id, original[0].id)
        XCTAssertTrue(store.observations.contains(standalone))
    }

    func testReviewRejectsConcurrentChangeAndInvalidIntervalWithoutLosingLogs() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let live = session(live: true); try store.startSession(live)
        let point = SessionLogLocation(latitude: 51, longitude: 4, name: "Plek", countryCode: "BE")
        try store.logLive(DiscoverFixtures.catalog[0], sessionID: live.id, at: start.addingTimeInterval(100), location: point)
        let original = store.observations(in: live)
        var review = live; review.endedAt = start.addingTimeInterval(50)
        XCTAssertThrowsError(try store.completeSession(review, logs: original, expectedLogs: original))
        var edited = original[0]; edited.locationName = "Gewijzigd"
        try store.save(edited, editing: true)
        review.endedAt = start.addingTimeInterval(300)
        XCTAssertThrowsError(try store.completeSession(review, logs: original, expectedLogs: original))
        XCTAssertEqual(store.observations(in: live), [edited])
        XCTAssertNotNil(store.activeSession)
    }

    func testReviewCanRemoveAndAddLogsAsOneTransaction() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let live = session(live: true); try store.startSession(live)
        let point = SessionLogLocation(latitude: 51, longitude: 4, name: "Plek", countryCode: "BE")
        try store.logLive(DiscoverFixtures.catalog[0], sessionID: live.id, at: start.addingTimeInterval(100), location: point)
        let original = store.observations(in: live)
        var added = original[0]; added.id = UUID(); added.observedAt = start.addingTimeInterval(200)
        var review = live; review.endedAt = start.addingTimeInterval(300)
        try store.completeSession(review, logs: [added], expectedLogs: original)
        XCTAssertEqual(store.observations(in: review), [added])
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertEqual(restored.observations, [added])
        XCTAssertNil(restored.activeSession)
    }

    func testInvalidTimesAndLocationsAreRejected() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        var invalid = session(live: false); invalid.endedAt = start.addingTimeInterval(-1)
        XCTAssertThrowsError(try store.addCompletedSession(invalid, species: []))
        invalid = session(live: true); invalid.latitude = 100
        XCTAssertThrowsError(try store.startSession(invalid))
        XCTAssertTrue(store.sessions.isEmpty)
    }
}

private struct FailingSessionPersistence: ObservationPersistence {
    func load() throws -> [Observation] { [] }
    func save(_ observations: [Observation]) throws { throw CocoaError(.fileWriteNoPermission) }
    func save(_ observations: [Observation], sessions: [BirdSession]) throws { throw CocoaError(.fileWriteNoPermission) }
}

private struct ReadOnlySessionPersistence: ObservationPersistence {
    let session: BirdSession
    func load() throws -> [Observation] { [] }
    func loadSessions() throws -> [BirdSession] { [session] }
    func save(_ observations: [Observation]) throws { throw CocoaError(.fileWriteNoPermission) }
    func save(_ observations: [Observation], sessions: [BirdSession]) throws { throw CocoaError(.fileWriteNoPermission) }
}

final class CountryProjectionTests: XCTestCase {
    private func log(_ species: String, country: String?, at: Double) -> Observation {
        var value = Observation(speciesID: species, taxonomyVersion: "test-v1", observedAt: Date(timeIntervalSince1970: at),
            locationName: "Plek", count: 1, notes: "", status: .confirmed)
        value.countryCode = country; return value
    }
    func testUniqueSpeciesPerCountryAndUnknownCountriesAreExcluded() {
        let records = [log("a", country: " be ", at: 1), log("a", country: "BE", at: 2),
            log("b", country: "BE", at: 3), log("a", country: "NL", at: 4),
            log("c", country: nil, at: 5), log("d", country: "ZZ", at: 6)]
        let rows = CountryProjection.countries(in: records)
        XCTAssertEqual(rows.first { $0.code == "BE" }?.speciesCount, 2)
        XCTAssertEqual(rows.first { $0.code == "NL" }?.speciesCount, 1)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first { $0.code == "BE" }?.flag, "🇧🇪")
    }
    func testCountryDetailAndDiscoveryOrderUseOnlyThatCountry() {
        let catalog = DiscoverFixtures.catalog
        let records = [log(catalog[0].id, country: "NL", at: 1), log(catalog[0].id, country: "BE", at: 30),
            log(catalog[1].id, country: "BE", at: 20), log(catalog[2].id, country: "NL", at: 40)]
        let filtered = CountryProjection.observations(in: "be", from: records)
        let rows = LogbookProjection.species(observations: filtered, catalog: catalog, sort: .lastLogged)
        XCTAssertEqual(rows.map(\.id), [catalog[0].id, catalog[1].id])
        XCTAssertTrue(CountryProjection.observations(in: "ZZ", from: records).isEmpty)
    }
}

@MainActor
final class GoalTests: XCTestCase {
    private func url() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }
    private func log(_ species: String) -> Observation {
        Observation(speciesID: species, taxonomyVersion: "test-v1", observedAt: Date(),
            locationName: "Test", count: 1, notes: "", status: .confirmed)
    }
    func testGoalProgressIncludesExistingAndNewLogsWithoutDuplicateCounts() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        try store.save(log("a"))
        let goal = BirdGoal(name: "Mijn vogels", speciesIDs: ["a", "b"])
        try store.addGoal(goal)
        XCTAssertEqual(goal.completedIDs(in: store.observations), ["a"])
        try store.save(log("a")); try store.save(log("b")); try store.save(log("outside"))
        XCTAssertEqual(goal.completedIDs(in: store.observations), ["a", "b"])
        XCTAssertTrue(goal.completedIDs(in: []).isEmpty)
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertEqual(restored.goals, [goal])
        XCTAssertEqual(restored.observations, store.observations)
        let archive = try JSONDecoder().decode(BirdingArchive.self, from: restored.exportArchiveData())
        XCTAssertEqual(archive.goals, [goal])
    }
    func testGoalsSurviveSessionWritesAndSessionLogsCompleteGoals() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let bird = DiscoverFixtures.catalog[0]
        let goal = BirdGoal(name: "Sessievogel", speciesIDs: [bird.id])
        try store.addGoal(goal)
        let now = Date()
        let live = BirdSession(locationName: "Test", latitude: 51, longitude: 4, countryCode: "BE",
            startedAt: now, endedAt: nil, isLive: true)
        try store.startSession(live)
        try store.logLive(bird, sessionID: live.id, at: now,
            location: SessionLogLocation(latitude: 51, longitude: 4, name: "Test", countryCode: "BE"))
        try store.finishSession(at: now.addingTimeInterval(10))
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertEqual(restored.goals, [goal])
        XCTAssertEqual(goal.completedIDs(in: restored.observations), [bird.id])
    }
    func testVersionTwoWithoutGoalsMigratesWithoutDroppingRecords() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let record = log("legacy")
        var archive = BirdingArchive(observations: [record], sessions: []); archive.version = 2
        try JSONEncoder().encode(archive).write(to: path)
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertNil(store.loadError); XCTAssertTrue(store.goals.isEmpty)
        try store.addGoal(BirdGoal(name: "Oude soort", speciesIDs: [record.speciesID]))
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertEqual(restored.observations, [record]); XCTAssertEqual(restored.goals.count, 1)
    }
    func testInvalidGoalsAndFailedWritesAreNotPublished() throws {
        XCTAssertThrowsError(try BirdGoal(name: " ", speciesIDs: ["a"]).validate())
        XCTAssertThrowsError(try BirdGoal(name: "Naam", speciesIDs: []).validate())
        XCTAssertThrowsError(try BirdGoal(name: "Naam", speciesIDs: ["a", "a"]).validate())
        let store = ObservationStore(persistence: FailingGoalPersistence())
        XCTAssertThrowsError(try store.addGoal(BirdGoal(name: "Naam", speciesIDs: ["a"])))
        XCTAssertTrue(store.goals.isEmpty)
    }
    func testCorruptGoalBlocksWritesAndPreservesArchive() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let data = try JSONEncoder().encode(BirdingArchive(observations: [log("a")], sessions: [],
            goals: [BirdGoal(name: "", speciesIDs: ["a"])]))
        try data.write(to: path)
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.save(log("b")))
        XCTAssertEqual(try Data(contentsOf: path), data)
    }
}

private struct FailingGoalPersistence: ObservationPersistence {
    func load() throws -> [Observation] { [] }
    func save(_ observations: [Observation]) throws { throw CocoaError(.fileWriteNoPermission) }
    func save(_ observations: [Observation], sessions: [BirdSession], goals: [BirdGoal]) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}

final class SpeciesCatalogSearchTests: XCTestCase {
    func testSearchMatchesDutchEnglishScientificAndWhitespace() {
        let catalog = DiscoverFixtures.catalog
        for term in ["ijsvogel", " COMMON KINGFISHER ", "Alcedo atthis"] {
            XCTAssertEqual(SpeciesCatalogSearch.results(for: term, in: catalog).map(\.id), [MockSpeciesRepository.kingfisher.id])
        }
        XCTAssertEqual(SpeciesCatalogSearch.results(for: "great tit", in: catalog).first?.scientificName, "Parus major")
    }
    func testEmptySearchIncludesEntireCatalogAndUnknownQueryIsEmpty() {
        let catalog = DiscoverFixtures.catalog
        XCTAssertEqual(Set(SpeciesCatalogSearch.results(for: " ", in: catalog).map(\.id)), Set(catalog.map(\.id)))
        XCTAssertTrue(SpeciesCatalogSearch.results(for: "geen-bestaande-soort", in: catalog).isEmpty)
        XCTAssertTrue(SpeciesCatalogSearch.results(for: "", in: []).isEmpty)
    }
    func testDiacriticsAndNameTiesHaveStableOrdering() {
        let a = Species(id: "a", taxonomyVersion: "test", dutchName: "Één vogel", englishName: "Test bird", scientificName: "Testus")
        let b = Species(id: "b", taxonomyVersion: "test", dutchName: "Één vogel", englishName: "Test bird", scientificName: "Testus")
        XCTAssertEqual(SpeciesCatalogSearch.results(for: "een", in: [b, a]).map(\.id), ["a", "b"])
    }
}

final class IdentificationAnalysisTests: XCTestCase {
    func testCandidatesRejectInvalidScoresAndKeepBestScorePerStableSpeciesID() {
        let bird = DiscoverFixtures.catalog[0], other = DiscoverFixtures.catalog[1]
        let rows = IdentificationCandidate.ranked([
            IdentificationCandidate(species: bird, score: 0.3), IdentificationCandidate(species: bird, score: 0.8),
            IdentificationCandidate(species: other, score: 0.6), IdentificationCandidate(species: other, score: .nan),
            IdentificationCandidate(species: other, score: 1.2)])
        XCTAssertEqual(rows.map(\.id), [bird.id, other.id])
        XCTAssertEqual(rows.first?.score, 0.8)
    }
    func testSonogramSilenceAndInvalidInputsAreEmptyOrDark() {
        XCTAssertTrue(SonogramAnalysis.column(samples: [], sampleRate: 32000).isEmpty)
        XCTAssertTrue(SonogramAnalysis.column(samples: [1], sampleRate: 0).isEmpty)
        XCTAssertTrue(SonogramAnalysis.column(samples: [1], sampleRate: 32000, bins: 1).isEmpty)
        XCTAssertTrue(SonogramAnalysis.column(samples: Array(repeating: 0, count: 1024), sampleRate: 32000).allSatisfy { $0 == 0 })
    }
    func testSonogramFindsSyntheticToneAtExpectedFrequencyBin() {
        let sampleRate = 32000.0
        let bin = 16
        let frequency = 250 * pow(10000.0 / 250, Double(bin) / 31)
        let samples = (0..<2048).map { Float(0.5 * sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
        let column = SonogramAnalysis.column(samples: samples, sampleRate: sampleRate)
        let peak = column.enumerated().max { $0.element < $1.element }?.offset
        XCTAssertEqual(peak, bin)
        XCTAssertTrue(column.allSatisfy { $0.isFinite && (0...1).contains($0) })
    }
}

@MainActor
final class PhotoIdentificationTests: XCTestCase {
    func testUnconfiguredProviderDoesNotInventResults() async {
        let model = PhotoIdentificationModel()
        await model.identify(Data([1]))
        XCTAssertTrue(model.candidates.isEmpty)
        XCTAssertNotNil(model.message)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.photo, Data([1]))
    }
    func testProviderSuggestionsAreRankedAndClearDoesNotRetainResults() async {
        let model = PhotoIdentificationModel(service: FixturePhotoIdentification())
        await model.identify(Data([1]))
        XCTAssertEqual(model.candidates.first?.id, DiscoverFixtures.catalog[1].id)
        model.clear()
        XCTAssertNil(model.photo); XCTAssertTrue(model.candidates.isEmpty); XCTAssertFalse(model.isLoading)
        await model.identify(Data())
        XCTAssertNotNil(model.message); XCTAssertNil(model.photo)
    }
}

private struct FixturePhotoIdentification: PhotoIdentificationService {
    func identify(photo: Data) async throws -> [IdentificationCandidate] {
        [IdentificationCandidate(species: DiscoverFixtures.catalog[0], score: 0.3),
         IdentificationCandidate(species: DiscoverFixtures.catalog[1], score: 0.7)]
    }
}

@MainActor
final class SoundPinningTests: XCTestCase {
    func testMultiplePinsSurviveReloadAndCanBeRemoved() throws {
        let name = "SoundPinningTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = DiscoverFixtures.catalog[0], second = DiscoverFixtures.catalog[1]
        let pins = SoundResultPins(defaults: defaults)
        pins.toggle(first); pins.toggle(second)
        let restored = SoundResultPins(defaults: defaults)
        XCTAssertEqual(restored.species.map(\.id), [first.id, second.id])
        restored.toggle(first)
        XCTAssertEqual(SoundResultPins(defaults: defaults).species.map(\.id), [second.id])
    }
    func testPinsKeepOrderAndRemainVisibleWhenNoLongerDetected() {
        let birds = DiscoverFixtures.catalog
        let rows = SoundResultOrdering.rows(candidates: [IdentificationCandidate(species: birds[0], score: 0.99),
            IdentificationCandidate(species: birds[1], score: 0.1)],
            pins: [PinnedSoundSpecies(birds[2]), PinnedSoundSpecies(birds[1])])
        XCTAssertEqual(rows.map(\.id), [birds[2].id, birds[1].id, birds[0].id])
        XCTAssertEqual(rows.map(\.isPinned), [true, true, false])
        XCTAssertEqual(SoundResultOrdering.rows(candidates: [], pins: [PinnedSoundSpecies(birds[2])]).first?.id, birds[2].id)
    }
    func testUnpinnedResultsRetainRankingAndAreNotDuplicated() {
        let birds = DiscoverFixtures.catalog
        let rows = SoundResultOrdering.rows(candidates: [IdentificationCandidate(species: birds[0], score: 0.2),
            IdentificationCandidate(species: birds[1], score: 0.8), IdentificationCandidate(species: birds[0], score: 0.1)], pins: [])
        XCTAssertEqual(rows.map(\.id), [birds[1].id, birds[0].id])
    }
}

final class SoundActivityTests: XCTestCase {
    func testOnlyRecentDetectionsHighlightAndStopClearsHighlight() {
        let now = Date(timeIntervalSince1970: 100)
        var activity = SoundActivity()
        activity.heard("a", at: now); activity.heard("b", at: now.addingTimeInterval(-5))
        XCTAssertEqual(activity.activeIDs(at: now, recording: true), ["a"])
        XCTAssertTrue(activity.activeIDs(at: now.addingTimeInterval(4), recording: true).isEmpty)
        XCTAssertTrue(activity.activeIDs(at: now, recording: false).isEmpty)
    }
    func testRepeatedDetectionExtendsHighlightAndOlderResultCannotShortenIt() {
        let now = Date(timeIntervalSince1970: 100)
        var activity = SoundActivity()
        activity.heard("a", at: now); activity.heard("a", at: now.addingTimeInterval(3))
        activity.heard("a", at: now.addingTimeInterval(1))
        XCTAssertEqual(activity.activeIDs(at: now.addingTimeInterval(5), recording: true), ["a"])
        XCTAssertTrue(activity.activeIDs(at: now.addingTimeInterval(-1), recording: true).isEmpty)
    }
}

final class BirdNETWindowTests: XCTestCase {
    func testThreeSecondWindowsHaveOneAndHalfSecondOverlap() {
        var accumulator = AudioWindowAccumulator()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertNil(accumulator.append(Array(repeating: 0, count: 16000), sampleRate: 8000, endedAt: now))
        let first = accumulator.append(Array(repeating: 1, count: 8000), sampleRate: 8000, endedAt: now)
        XCTAssertEqual(first?.samples.count, 24000)
        XCTAssertEqual(accumulator.bufferedCount, 12000)
        let next = accumulator.append(Array(repeating: 2, count: 12000), sampleRate: 8000, endedAt: now)
        XCTAssertEqual(next?.samples.prefix(4000).first, 0)
        XCTAssertEqual(next?.samples.last, 2)
        XCTAssertEqual(accumulator.bufferedCount, 12000)
    }
    func testRateChangesResetAndOversizedInputsRemainBounded() {
        var accumulator = AudioWindowAccumulator()
        _ = accumulator.append(Array(repeating: 1, count: 12000), sampleRate: 8000, endedAt: Date())
        XCTAssertNil(accumulator.append(Array(repeating: 2, count: 16000), sampleRate: 16000, endedAt: Date()))
        XCTAssertEqual(accumulator.bufferedCount, 16000)
        let window = accumulator.append(Array(repeating: 3, count: 200000), sampleRate: 16000, endedAt: Date())
        XCTAssertEqual(window?.samples.count, 48000)
        XCTAssertLessThanOrEqual(accumulator.bufferedCount, 48000)
        XCTAssertNil(accumulator.append([1], sampleRate: .nan, endedAt: Date()))
    }
    func testModelInputIsFixedLengthFiniteAndSilenceIsSkipped() throws {
        let input = LiveAudioWindow(samples: [2, -2, 0.5], sampleRate: 32000, endedAt: Date())
        let samples = try BirdNETAudio.resampled(input)
        XCTAssertEqual(samples.count, 96000)
        XCTAssertEqual(Array(samples.prefix(3)), [1, -1, 0.5])
        XCTAssertTrue(BirdNETAudio.isSilent(Array(repeating: 0, count: 96000)))
        XCTAssertFalse(BirdNETAudio.isSilent(Array(repeating: 0.1, count: 96000)))
        XCTAssertThrowsError(try BirdNETAudio.resampled(LiveAudioWindow(samples: [.nan], sampleRate: 32000, endedAt: Date())))
    }
    func testNative48kAudioResamplesToThreeSecondsAt32k() throws {
        let samples = (0..<144000).map { Float(0.25 * sin(2 * Double.pi * 1000 * Double($0) / 48000)) }
        let converted = try BirdNETAudio.resampled(LiveAudioWindow(samples: samples, sampleRate: 48000, endedAt: Date()))
        XCTAssertEqual(converted.count, 96000)
        XCTAssertTrue(converted.allSatisfy(\.isFinite))
        XCTAssertFalse(BirdNETAudio.isSilent(converted))
    }
    func testBirdNETLabelsPreserveExistingAppIDsAndKeepUnknownSpeciesExplicit() {
        let known = BirdNETLabel(index: 0, birdnetID: "BN00268", scientificName: "Alcedo atthis", dutchName: "IJsvogel", englishName: "Common Kingfisher")
        XCTAssertEqual(known.species.id, MockSpeciesRepository.kingfisher.id)
        let external = BirdNETLabel(index: 1, birdnetID: "BN-example", scientificName: "Testus example", dutchName: "Testvogel", englishName: "Test bird")
        XCTAssertEqual(external.species.id, "birdnet-v3:BN-example")
        XCTAssertEqual(external.species.taxonomyVersion, "BirdNET+ labels v0.5-Nov2026")
    }
}

@MainActor
final class WorldSpeciesCatalogTests: XCTestCase {
    func testBundledCatalogIncludesFullChecklistAndIndependentSoundCoverage() {
        XCTAssertNil(SpeciesGuideCatalog.loadError)
        XCTAssertEqual(SpeciesGuideCatalog.metadata?.checklistSpecies, 11172)
        XCTAssertEqual(SpeciesGuideCatalog.species.count, 11173)
        XCTAssertEqual(Set(SpeciesGuideCatalog.species.map(\.id)).count, 11173)
        XCTAssertEqual(SpeciesGuideCatalog.metadata?.soundSpecies, 9788)
        XCTAssertEqual(SpeciesGuideCatalog.metadata?.withoutSound, 1385)
        XCTAssertEqual(Set(SpeciesGuideCatalog.species.compactMap { $0.family?.id }).count, 250)
    }
    func testSpeciesOutsideSoundModelIsSearchableAndCanBeLogged() throws {
        let bird = try XCTUnwrap(GuideSpeciesRepository().search("Raphus cucullatus").first)
        XCTAssertNil(SpeciesGuideCatalog.record(id: bird.id)?.soundIndex)
        let store = ObservationStore(persistence: PreviewObservationPersistence())
        try store.save(Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion,
            observedAt: Date(), locationName: "Test", count: 1, notes: "", status: .confirmed))
        XCTAssertEqual(store.logStatus(for: bird.id), .logged)
        let rows = LogbookProjection.species(observations: store.observations, catalog: [], sort: .family)
        XCTAssertEqual(rows.first?.species.scientificName, "Raphus cucullatus")
    }
    func testExistingSampleAndSoundIDsRemainResolvable() throws {
        for sample in DiscoverFixtures.catalog {
            let stored = try XCTUnwrap(SpeciesGuideCatalog.species(id: sample.id))
            XCTAssertEqual(stored.scientificName, sample.scientificName)
            XCTAssertEqual(stored.taxonomyVersion, sample.taxonomyVersion)
        }
        let crow = try XCTUnwrap(GuideSpeciesRepository().search("Corvus cornix").first)
        XCTAssertFalse(try XCTUnwrap(SpeciesGuideCatalog.record(id: crow.id)).checklistSpecies)
        XCTAssertNotNil(SpeciesGuideCatalog.record(id: crow.id)?.soundIndex)
    }
    func testAliasesAreSearchableWithoutChangingTheSavedID() {
        let bird = Species(id: "stable", taxonomyVersion: "test", dutchName: "Nieuwe naam", englishName: "New name",
            scientificName: "Newus name", aliases: ["Oude vogelnaam", "Oldus name"])
        XCTAssertEqual(SpeciesCatalogSearch.results(for: "oude vogelnaam", in: [bird]).map(\.id), ["stable"])
        XCTAssertEqual(SpeciesCatalogSearch.results(for: "oldus", in: [bird]).map(\.id), ["stable"])
    }
    func testLongDutchNameAndFamilyResolveFromWorldCatalog() throws {
        let hornbill = try XCTUnwrap(GuideSpeciesRepository().search("dubbelhoornige neushoornvogel").first)
        XCTAssertEqual(hornbill.scientificName, "Buceros bicornis")
        XCTAssertEqual(hornbill.family?.id, "Bucerotidae")
        XCTAssertEqual(SpeciesMediaRole.detailSlides, [.dynamic, .front, .rear, .flight])
    }
}

final class HabitatSceneTests: XCTestCase {
    private var scene: HabitatScene {
        HabitatScene(id: "forest", name: "Bos", group: "Bos", assetName: "habitat-forest", illustrationBrief: "Stammen en ondergroei")
    }
    private func assignment(id: String = "bird", primary: String = "forest", status: String = "source-checked") -> SpeciesHabitatAssignment {
        SpeciesHabitatAssignment(speciesID: id, scientificName: "Testus bird", primarySceneID: primary,
            secondarySceneIDs: [], reviewStatus: status, reviewedAt: "2026-11-19", sourceURLs: [URL(string: "https://example.org/habitat")!])
    }
    func testSharedSceneResolvesForMultipleSpecies() throws {
        let library = try HabitatSceneLibrary(scenes: [scene], assignments: [assignment(id: "a"), assignment(id: "b")])
        XCTAssertEqual(library.primaryScene(for: "a")?.assetName, library.primaryScene(for: "b")?.assetName)
    }
    func testSourceDerivedAssignmentsResolveWithoutClaimingIndividualReview() throws {
        let library = try HabitatSceneLibrary(scenes: [scene], assignments: [assignment(status: "source-derived")])
        XCTAssertEqual(library.primaryScene(for: "bird")?.id, "forest")
        XCTAssertEqual(library.assignment(for: "bird")?.reviewStatus, "source-derived")
    }
    func testUnassignedAndDraftSpeciesHaveNoFooterScene() throws {
        let library = try HabitatSceneLibrary(scenes: [scene], assignments: [assignment(status: "draft")])
        XCTAssertNil(library.primaryScene(for: "bird"))
        XCTAssertNil(library.primaryScene(for: "unknown"))
    }
    func testInvalidLinksAndDuplicateAssignmentsAreRejected() {
        XCTAssertThrowsError(try HabitatSceneLibrary(scenes: [scene], assignments: [assignment(primary: "missing")]))
        XCTAssertThrowsError(try HabitatSceneLibrary(scenes: [scene], assignments: [assignment(), assignment()]))
        XCTAssertThrowsError(try HabitatSceneLibrary(scenes: [scene, scene], assignments: []))
    }
    func testBundledClassificationPreservesKingfisherSceneAndSharesWoodland() throws {
        XCTAssertNil(HabitatSceneCatalog.loadError)
        XCTAssertEqual(HabitatSceneCatalog.scenes.count, 33)
        XCTAssertEqual(HabitatSceneCatalog.assignments.count, 11130)
        XCTAssertEqual(HabitatSceneCatalog.primaryScene(for: MockSpeciesRepository.kingfisher)?.assetName, "KingfisherHabitat")
        let tit = try XCTUnwrap(SpeciesGuideCatalog.species(id: "sample-parus-major"))
        let woodpecker = try XCTUnwrap(SpeciesGuideCatalog.species(id: "sample-dendrocopos-major"))
        XCTAssertEqual(HabitatSceneCatalog.primaryScene(for: tit)?.id, "temperate-woodland")
        XCTAssertEqual(HabitatSceneCatalog.primaryScene(for: tit)?.id, HabitatSceneCatalog.primaryScene(for: woodpecker)?.id)
    }
}
