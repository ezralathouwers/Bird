import XCTest
@preconcurrency import AVFoundation
import UIKit
import MapKit
import CoreText
import CryptoKit
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

    func testBirdLifeSeasonOriginAndPresenceRemainSeparate() throws {
        let features: [[String: Any]] = [
            [1, 1, 1], [1, 1, 2], [1, 3, 3], [1, 1, 4], [5, 1, 1], [1, 4, 1]
        ].map { codes in
            ["type": "Feature", "properties": ["presence": codes[0], "origin": codes[1], "seasonal": codes[2]],
             "geometry": ["type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,1],[0,0]]]]]
        }
        let data = try JSONSerialization.data(withJSONObject: ["type": "FeatureCollection",
            "providerID": "birdlife-datazone", "source": "Fictional test", "license": "Test only",
            "version": "test", "features": features])
        let dataset = try BundledSpeciesRangeRepository.decode(data)
        XCTAssertEqual(dataset.areas.count, 4)
        XCTAssertEqual(dataset.areas.compactMap(\.season), [.resident, .breeding, .nonBreeding, .passage])
        XCTAssertTrue(dataset.areas[2].introduced)
        XCTAssertFalse(dataset.areas[0].introduced)
    }

    func testBirdLifeUnknownSeasonCannotBecomeUnlabelledCurrentRange() throws {
        let data = fixture.replacingOccurrences(of: "\"source\":\"Unit test fixture\"",
            with: "\"providerID\":\"birdlife-datazone\",\"source\":\"Unit test fixture\"")
            .replacingOccurrences(of: "\"properties\":{}", with: "\"properties\":{\"presence\":1,\"origin\":1,\"seasonal\":99}")
        XCTAssertThrowsError(try BundledSpeciesRangeRepository.decode(Data(data.utf8)))
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

    func testRankingCountsDistinctChecklistsWithinAreaAndThreeDays() {
        let reports = [report(first, checklist: "A"), report(first, checklist: "A"),
            report(first, checklist: "B"), report(second, checklist: "C"),
            report(second, checklist: "old", daysAgo: 8), report(second, checklist: "future", daysAgo: -1),
            report(second, checklist: "far", latitude: 10), report(second, checklist: "")]
        let ranked = DiscoverRanking.ranked(reports, query: query)
        XCTAssertEqual(ranked.map(\.id), [first.id, second.id])
        XCTAssertEqual(ranked.map(\.reportCount), [2, 1])
    }

    func testBoundaryAndTieOrderAreDeterministic() {
        let ranked = DiscoverRanking.ranked([report(first, checklist: "A", daysAgo: 3),
                                            report(second, checklist: "B", daysAgo: 0)], query: query)
        XCTAssertEqual(ranked.map(\.species.dutchName), ["Koolmees", "Merel"])
    }

    func testProviderRecencyPreservesOrderRatherThanNamesOrReportCounts() {
        let newestFirst = [report(second, checklist: "latest"),
                           report(first, checklist: "older", daysAgo: 2),
                           report(first, checklist: "also-older", daysAgo: 3)]
        let rows = DiscoverRanking.ranked(newestFirst, query: query, ordering: .providerRecency)
        XCTAssertEqual(rows.map(\.id), [second.id, first.id])
        XCTAssertEqual(rows.map(\.reportCount), [1, 2])
        let reverse = DiscoverRanking.ranked([report(first, checklist: "latest"),
                                             report(second, checklist: "older", daysAgo: 2)],
                                            query: query, ordering: .providerRecency)
        XCTAssertEqual(reverse.map(\.id), [first.id, second.id]) // Must not re-sort alphabetically.
    }

    func testFiveKilometerRecencyFilterKeepsOnlyValidReportsBeforeOrdering() {
        let local = DiscoverQuery(latitude: 0, longitude: 0, now: now,
                                  radiusKilometers: DiscoverQuery.nearbyRadiusKilometers)
        let rows = DiscoverRanking.ranked([
            report(first, checklist: "outside", latitude: 0.046), // About 5.1 km away.
            report(first, checklist: "old", daysAgo: 8),
            report(first, checklist: "future", daysAgo: -1),
            report(second, checklist: "inside", latitude: 0.044), // About 4.9 km away.
            report(first, checklist: "valid-older", daysAgo: 2)
        ], query: local, ordering: .providerRecency)
        XCTAssertEqual(local.radiusKilometers, 5)
        XCTAssertEqual(rows.map(\.id), [second.id, first.id])
        XCTAssertEqual(rows.map(\.reportCount), [1, 1])
    }

    func testEBirdChecklistLinksAreStrictAndFollowTheDisplayedReport() {
        XCTAssertEqual(DiscoverRanking.checklistURL("S123456")?.absoluteString, "https://ebird.org/checklist/S123456?siteLanguage=nl&locale=nl")
        XCTAssertNil(DiscoverRanking.checklistURL("mock-checklist"))
        XCTAssertNil(DiscoverRanking.checklistURL("S12/../../other"))
        let row = DiscoverRanking.ranked([report(first, checklist: "S987654")], query: query).first
        XCTAssertEqual(row?.observationURL?.absoluteString, "https://ebird.org/checklist/S987654?siteLanguage=nl&locale=nl")
        let fallback = DiscoverRanking.ranked([report(first, checklist: "unavailable"), report(first, checklist: "S987654")], query: query).first
        XCTAssertEqual(fallback?.observationURL?.absoluteString, "https://ebird.org/checklist/S987654?siteLanguage=nl&locale=nl")
        XCTAssertNil(DiscoverRanking.ranked([report(first, checklist: "unavailable")], query: query).first?.observationURL)
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
    func testInvalidKeyShowsConnectionControlsAndResetClearsOldRequestState() async {
        let model = DiscoverViewModel(repository: EBirdDiscoverRepository(
            keys: EBirdFixtureKeyStore(), client: EBirdFixtureHTTP(status: 403)))
        await model.load(query: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: DiscoverQuery.nearbyRadiusKilometers))
        XCTAssertTrue(model.needsConnection)
        XCTAssertNotNil(model.message)
        model.reset()
        XCTAssertFalse(model.needsConnection)
        XCTAssertNil(model.message)
        XCTAssertNil(model.loadedQuery)
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertFalse(model.isLoading)
    }

    func testIncompleteProviderCannotProduceMisleadingFrequencyRanking() async {
        let model = DiscoverViewModel(repository: IncompleteDiscoverFixture())
        await model.load(query: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: 25))
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertNotNil(model.message)
        XCTAssertNil(model.loadedQuery)
    }

    func testDemoIsExplicitAndMissingProviderDoesNotInventLiveRows() async {
        let model = DiscoverViewModel(repository: UnconfiguredDiscoverRepository())
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
        XCTAssertThrowsError(try restored.logLive(DiscoverFixtures.catalog[0], sessionID: live.id, at: start.addingTimeInterval(200), location: point))
        try restored.logLive(DiscoverFixtures.catalog[1], sessionID: live.id, at: start.addingTimeInterval(200), location: point)
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
    func testCountriesRankBySpeciesCountThenObservationCount() {
        let records = [log("a", country: "BE", at: 1), log("a", country: "BE", at: 2),
                       log("a", country: "BE", at: 3), log("a", country: "NL", at: 4),
                       log("b", country: "NL", at: 5)]
        let countries = CountryProjection.countries(in: records)
        XCTAssertEqual(countries.map(\.code), ["NL", "BE"])
        XCTAssertEqual(countries.map(\.observationCount), [2,3])
        XCTAssertEqual(countries.map(\.speciesCount), [2,1])
        XCTAssertEqual(countries, CountryProjection.countries(in: Array(records.reversed())))
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
    func testFavoriteSelectionIsUniqueAutoSelectedAndClearedWhenDeselected() {
        var selection = GoalSpeciesSelection()
        selection.chooseFavorite("a")
        XCTAssertEqual(selection.ids, ["a"]); XCTAssertEqual(selection.favoriteID, "a")
        selection.chooseFavorite("b")
        XCTAssertEqual(selection.ids, ["a", "b"]); XCTAssertEqual(selection.favoriteID, "b")
        selection.toggle("a"); XCTAssertEqual(selection.favoriteID, "b")
        selection.toggle("b"); XCTAssertNil(selection.favoriteID); XCTAssertTrue(selection.ids.isEmpty)
    }
    func testLegacyGoalWithoutFavoriteDecodesAndInvalidFavoriteIsRejected() throws {
        let original = BirdGoal(name: "Oude checklist", speciesIDs: ["a"])
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        dictionary.removeValue(forKey: "favoriteSpeciesID")
        let decoded = try JSONDecoder().decode(BirdGoal.self, from: JSONSerialization.data(withJSONObject: dictionary))
        XCTAssertNil(decoded.favoriteSpeciesID); XCTAssertEqual(decoded.id, original.id)
        XCTAssertNoThrow(try decoded.validate())
        var invalid = decoded; invalid.favoriteSpeciesID = "outside"
        XCTAssertThrowsError(try invalid.validate())
    }
    func testEditedFavoritePersistsWithoutChangingIdentityCreationDateOrOtherRecords() throws {
        let path = url(); defer { try? FileManager.default.removeItem(at: path) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let observation = log("a"); try store.save(observation)
        let original = BirdGoal(name: "Origineel", speciesIDs: ["a", "unknown-stable-id"])
        let other = BirdGoal(name: "Andere", speciesIDs: ["b"])
        try store.addGoal(original); try store.addGoal(other)
        var edited = original; edited.name = "Bewerkt"; edited.favoriteSpeciesID = "unknown-stable-id"
        edited.createdAt = original.createdAt.addingTimeInterval(100)
        try store.updateGoal(edited)
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: path))
        let saved = try XCTUnwrap(restored.goals.first { $0.id == original.id })
        XCTAssertEqual(saved.name, "Bewerkt"); XCTAssertEqual(saved.favoriteSpeciesID, "unknown-stable-id")
        XCTAssertEqual(saved.createdAt, original.createdAt); XCTAssertEqual(saved.speciesIDs, original.speciesIDs)
        XCTAssertEqual(restored.goals.last, other); XCTAssertEqual(restored.observations, [observation])
        let archive = try JSONDecoder().decode(BirdingArchive.self, from: restored.exportArchiveData())
        XCTAssertEqual(archive.goals?.first?.favoriteSpeciesID, "unknown-stable-id")
        let before = try Data(contentsOf: path)
        edited.favoriteSpeciesID = "not-selected"
        XCTAssertThrowsError(try store.updateGoal(edited))
        XCTAssertThrowsError(try store.updateGoal(BirdGoal(name: "Ontbreekt", speciesIDs: ["a"])))
        XCTAssertEqual(try Data(contentsOf: path), before)
    }
    func testFailedGoalUpdateDoesNotPublishChanges() throws {
        let original = BirdGoal(name: "Origineel", speciesIDs: ["a"])
        let persistence = FailingGoalUpdatePersistence(goal: original)
        let store = ObservationStore(persistence: persistence)
        var edited = original; edited.name = "Bewerkt"; edited.favoriteSpeciesID = "a"
        XCTAssertThrowsError(try store.updateGoal(edited))
        XCTAssertEqual(store.goals, [original])
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
    func testPinsAreSessionLocalAndResetForNewListeningSession() throws {
        let name = "SoundPinningTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = DiscoverFixtures.catalog[0], second = DiscoverFixtures.catalog[1]
        defaults.set(try JSONEncoder().encode([PinnedSoundSpecies(first)]), forKey: "sound-id-pinned-species-v1")
        let pins = SoundResultPins(defaults: defaults)
        XCTAssertTrue(pins.species.isEmpty)
        pins.toggle(first); pins.toggle(second)
        let restored = SoundResultPins(defaults: defaults)
        XCTAssertTrue(restored.species.isEmpty)
        pins.toggle(first)
        XCTAssertEqual(pins.species.map(\.id), [second.id])
        pins.reset()
        XCTAssertTrue(pins.species.isEmpty)
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
        XCTAssertEqual(SpeciesGuideCatalog.species.count, 11022)
        XCTAssertEqual(Set(SpeciesGuideCatalog.species.map(\.id)).count, 11022)
        XCTAssertEqual(SpeciesGuideCatalog.metadata?.soundSpecies, 9788)
        XCTAssertEqual(SpeciesGuideCatalog.metadata?.withoutSound, 1385)
        XCTAssertEqual(Set(SpeciesGuideCatalog.species.compactMap { $0.family?.id }).count, 249)
    }
    func testHistoricalExtinctSpeciesStillResolvesWithoutAppearingInSearch() throws {
        let bird = try XCTUnwrap(SpeciesGuideCatalog.species(id: "avilist:def95927"))
        XCTAssertTrue(GuideSpeciesRepository().search("Raphus cucullatus").isEmpty)
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
        XCTAssertEqual(HabitatSceneCatalog.primaryScene(for: MockSpeciesRepository.kingfisher)?.assetName, "HabitatAtlas1")
        let tit = try XCTUnwrap(SpeciesGuideCatalog.species(id: "sample-parus-major"))
        let woodpecker = try XCTUnwrap(SpeciesGuideCatalog.species(id: "sample-dendrocopos-major"))
        XCTAssertEqual(HabitatSceneCatalog.primaryScene(for: tit)?.id, "temperate-woodland")
        XCTAssertEqual(HabitatSceneCatalog.primaryScene(for: tit)?.id, HabitatSceneCatalog.primaryScene(for: woodpecker)?.id)
    }
}

final class SpeciesRangeSourceTests: XCTestCase {
    private func configuration(access: String = "awaitingPermission", version: String? = nil,
                               license: String? = nil, citation: String? = nil) throws -> Data {
        var value: [String: Any] = [
            "providerID": "birdlife-datazone", "name": "BirdLife International — DataZone",
            "homepage": "https://datazone.birdlife.org/",
            "requestURL": "https://datazone.birdlife.org/contact-us/request-our-data",
            "termsURL": "https://datazone.birdlife.org/terms-and-conditions", "access": access
        ]
        value["datasetVersion"] = version; value["licenseNotice"] = license; value["citation"] = citation
        return try JSONSerialization.data(withJSONObject: value)
    }
    func testPendingSourceDoesNotRequireInventedReleaseOrLicense() throws {
        let source = try SpeciesRangeSource.decode(configuration())
        XCTAssertEqual(source.access, .awaitingPermission)
        XCTAssertNil(source.datasetVersion)
    }
    func testApprovedAccessDoesNotInventDatasetMetadata() throws {
        let source = try SpeciesRangeSource.decode(configuration(access: "approvedAwaitingFiles"))
        XCTAssertEqual(source.access, .approvedAwaitingFiles)
        XCTAssertNil(source.datasetVersion)
        XCTAssertNil(source.licenseNotice)
        XCTAssertNil(source.citation)
    }
    func testLicensedSourceRequiresReleaseLicenseAndCitation() throws {
        XCTAssertThrowsError(try SpeciesRangeSource.decode(configuration(access: "licensed")))
        XCTAssertThrowsError(try SpeciesRangeSource.decode(configuration(access: "licensed", version: "test", license: " ", citation: "test")))
        let source = try SpeciesRangeSource.decode(configuration(access: "licensed", version: "test", license: "Test fixture only", citation: "Test citation"))
        XCTAssertEqual(source.access, .licensed)
    }
    func testUnrecognizedAccessCannotEnableData() throws {
        XCTAssertThrowsError(try SpeciesRangeSource.decode(configuration(access: "enabled")))
    }
    func testConfiguredRepositoryReportsApprovedAccessWithMissingFiles() throws {
        // Never depend on whether the developer has installed real private maps.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "test.empty-birdlife"], format: .xml, options: 0)
        try plist.write(to: folder.appendingPathComponent("Info.plist"))
        try configuration(access: "approvedAwaitingFiles").write(to: folder.appendingPathComponent("SpeciesRangeSource.json"))
        let bundle = try XCTUnwrap(Bundle(url: folder))
        XCTAssertTrue(PrivateBirdLifeRangeRepository(bundle: bundle).diagnostic(speciesID: "sample-alcedo-atthis")
            .contains("Privékaartpakket in deze app: ontbreekt"))
        XCTAssertThrowsError(try ConfiguredSpeciesRangeRepository(bundle: bundle).load(speciesID: "sample-alcedo-atthis")) {
            guard case RangeDataError.awaitingFiles = $0 else {
                return XCTFail("Expected approved BirdLife access with missing files, got \($0)")
            }
        }
    }
}

final class PhotoSimilarityTests: XCTestCase {
    func testUnknownOrNonBirdWinnerAbstains() {
        XCTAssertTrue(PhotoSimilarity.accepted([("bird", 0.4), (nil, 0.6)]).isEmpty)
        XCTAssertTrue(PhotoSimilarity.accepted([("bird", 0.005)]).isEmpty)
        XCTAssertTrue(PhotoSimilarity.accepted([("bird", 0.5), (nil, 0.499)]).isEmpty)
    }
    func testDuplicateSpeciesDoNotOccupyMultipleResults() {
        let ranked = PhotoSimilarity.accepted([("a", 0.7), ("a", 0.8), ("b", 0.76), (nil, 0.3)])
        XCTAssertEqual(ranked.map(\.0), ["a", "b"])
        XCTAssertEqual(ranked.first?.1, 0.8)
    }
    func testAtMostThreeFiniteSuggestions() {
        let rows: [(String?, Float)] = (0..<10).map { ("bird-\($0)", Float(0.9 - Double($0) * 0.01)) }
        XCTAssertEqual(PhotoSimilarity.accepted(rows + [("invalid", .nan)]).count, 3)
    }
    func testInvalidEmbeddingsAreRejected() {
        XCTAssertNil(PhotoSimilarity.normalized([0, 0]))
        XCTAssertNil(PhotoSimilarity.normalized([.infinity, 1]))
        XCTAssertNil(PhotoSimilarity.normalized([.nan, 1]))
        let normalized = PhotoSimilarity.normalized([3, 4])
        XCTAssertEqual(normalized?.first ?? 0, 0.6, accuracy: 0.00001)
    }
    func testBundledPhotoLabelsResolveToCatalogAndKeepRejectionClasses() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "BioCLIPLabels", withExtension: "json"))
        let ids = try JSONDecoder().decode([String?].self, from: Data(contentsOf: url))
        XCTAssertEqual(ids.count, 15331)
        XCTAssertEqual(Set(ids.compactMap { $0 }).count, 9818)
        XCTAssertTrue(ids.contains { $0 == nil })
        XCTAssertTrue(ids.compactMap { $0 }.allSatisfy { SpeciesGuideCatalog.species(id: $0) != nil })
    }
}

@MainActor
final class PhotoPreprocessingTests: XCTestCase {
    func testRGBNormalizationOfUniformRedPhoto() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80), format: format).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        }
        let data = try XCTUnwrap(image.pngData())
        let pixels = try BioCLIPPhotoService.pixels(data)
        XCTAssertEqual(pixels.shape.map(\.intValue), [1, 3, 224, 224])
        XCTAssertEqual(pixels[0].floatValue, (1 - 0.48145466) / 0.26862954, accuracy: 0.005)
        XCTAssertEqual(pixels[224 * 224].floatValue, -0.4578275 / 0.26130258, accuracy: 0.005)
        XCTAssertEqual(pixels[2 * 224 * 224].floatValue, -0.40821073 / 0.27577711, accuracy: 0.005)
    }
    func testInvalidPhotoIsRejectedBeforeInference() {
        XCTAssertThrowsError(try BioCLIPPhotoService.pixels(Data("invalid".utf8)))
    }
}

@MainActor
final class HabitatArtworkTests: XCTestCase {
    func testAllScenesHaveDistinctValidPanelsAndRenderableArtwork() async throws {
        let scenes = HabitatSceneCatalog.scenes
        XCTAssertEqual(scenes.count, 33)
        var regions = Set<String>()
        for scene in scenes {
            let region = try XCTUnwrap(scene.artworkRegion)
            XCTAssertTrue(region.isValid, scene.id)
            XCTAssertTrue(regions.insert("\(scene.assetName):\(region.x),\(region.y),\(region.width),\(region.height)").inserted)
            let loaded = await HabitatArtworkCache.image(for: scene)
            let image = try XCTUnwrap(loaded, scene.id)
            XCTAssertGreaterThan(image.size.width, image.size.height)
        }
        XCTAssertEqual(Set(scenes.map(\.assetName)).count, 3)
    }
    func testFooterHasSynchronousSourceBeforeAsyncColorPreparation() throws {
        for scene in HabitatSceneCatalog.scenes {
            let source = try XCTUnwrap(HabitatArtworkCache.sourceImage(for: scene), scene.id)
            XCTAssertGreaterThan(source.size.width, 0)
            XCTAssertGreaterThan(source.size.height, 0)
        }
    }
    func testOutOfBoundsAndNonfiniteRegionsAreRejected() {
        let invalid = [HabitatArtworkRegion(x: -0.1, y: 0, width: 0.5, height: 0.5),
            HabitatArtworkRegion(x: 0.9, y: 0, width: 0.5, height: 0.5),
            HabitatArtworkRegion(x: 0, y: 0, width: 0, height: 0.5),
            HabitatArtworkRegion(x: .nan, y: 0, width: 0.5, height: 0.5)]
        for region in invalid { XCTAssertFalse(region.isValid) }
    }
}

final class SpeciesDetailsTests: XCTestCase {
    func testReportedWingspanFormatsWithoutApproximation() {
        let range = SpeciesWingspan(minimumCM: 24, maximumCM: 26, method: "reported", sourceScientificName: "Alcedo atthis", sourceURL: URL(string: "https://example.org")!)
        XCTAssertTrue(range.isValid)
        XCTAssertEqual(range.displayValue, "24–26 cm")
        let single = SpeciesWingspan(minimumCM: 25, maximumCM: 25, method: "reported", sourceScientificName: "Alcedo atthis", sourceURL: URL(string: "https://example.org")!)
        XCTAssertEqual(single.displayValue, "25 cm")
    }
    func testUnknownMethodAndInvalidWingspansAreRejected() {
        for span in [SpeciesWingspan(minimumCM: 26, maximumCM: 24, method: "reported", sourceScientificName: "Test", sourceURL: URL(string: "https://example.org")!),
                     SpeciesWingspan(minimumCM: 24, maximumCM: 26, method: "predicted", sourceScientificName: "Test", sourceURL: URL(string: "https://example.org")!)] {
            XCTAssertFalse(span.isValid)
        }
    }
    func testWikidataValuesRemainSingleAndRequireAnEntitySource() {
        let source = URL(string: "https://www.wikidata.org/wiki/Q123")!
        XCTAssertTrue(SpeciesWingspan(minimumCM: 50, maximumCM: 50, method: "source-reported-wikidata", sourceScientificName: "Test", sourceURL: source).isValid)
        XCTAssertFalse(SpeciesWingspan(minimumCM: 40, maximumCM: 60, method: "source-reported-wikidata", sourceScientificName: "Test", sourceURL: source).isValid)
        XCTAssertFalse(SpeciesWingspan(minimumCM: 50, maximumCM: 50, method: "source-reported-wikidata", sourceScientificName: "Test", sourceURL: URL(string: "https://example.org")!).isValid)
    }
    func testBundledCoveragePreservesMissingValuesAndKingfisherOverride() throws {
        XCTAssertNil(SpeciesDetailsCatalog.loadError)
        let rows = SpeciesGuideCatalog.species.compactMap { SpeciesDetailsCatalog.details(for: $0.id) }
        XCTAssertEqual(rows.count, 11022)
        XCTAssertEqual(rows.filter { $0.bio != nil }.count, 11003)
        XCTAssertNil(SpeciesWingspanEstimatesCatalog.loadError)
        XCTAssertEqual(rows.filter { $0.wingspan != nil && $0.wingspan?.isEstimated == false }.count, 1880)
        XCTAssertEqual(rows.filter { $0.wingspan?.isEstimated == true }.count, 7910)
        XCTAssertEqual(rows.filter { $0.wingspan != nil }.count, 9790)
        XCTAssertTrue(rows.contains { $0.bio == nil })
        XCTAssertEqual(SpeciesDetailsCatalog.details(for: "sample-alcedo-atthis")?.wingspan?.displayValue, "24–26 cm")
        XCTAssertNil(SpeciesDetailsCatalog.details(for: "not-a-species"))
    }
    func testEstimatedFallbackKeepsReportedPrecedenceAndFormatting() {
        let estimate = SpeciesWingspan(minimumCM: 42, maximumCM: 42, method: "estimated-wingspan-game", sourceScientificName: "Example bird", sourceURL: URL(string: "https://navarog.github.io/wingsearch/")!)
        XCTAssertTrue(estimate.isValid)
        XCTAssertTrue(estimate.isEstimated)
        XCTAssertEqual(estimate.displayValue, "42 cm")
        let reported = SpeciesWingspan(minimumCM: 24, maximumCM: 26, method: "reported", sourceScientificName: "Example bird", sourceURL: URL(string: "https://example.org")!)
        let details = SpeciesDetails(speciesID: "id", scientificName: "Example bird", bio: nil, bioMethod: nil, bioSourceURLs: [], wingspan: reported)
        XCTAssertEqual(details.addingFallbackWingspan(estimate).wingspan?.displayValue, "24–26 cm")
        let empty = SpeciesDetails(speciesID: "id", scientificName: "Example bird", bio: nil, bioMethod: nil, bioSourceURLs: [], wingspan: nil)
        XCTAssertEqual(empty.addingFallbackWingspan(estimate).wingspan?.displayValue, "42 cm")
        let invalidRange = SpeciesWingspan(minimumCM: 40, maximumCM: 44, method: "estimated-fox-model", sourceScientificName: "Example bird", sourceURL: URL(string: "https://doi.org/10.6084/m9.figshare.32089083.v1")!)
        XCTAssertFalse(invalidRange.isValid)
        XCTAssertNil(empty.addingFallbackWingspan(invalidRange).wingspan)
    }
}

final class SpeciesArtworkKeyTests: XCTestCase {
    func testNamespacedArtworkKeysDoNotChangePersistentIDs() throws {
        let bird = try XCTUnwrap(SpeciesGuideCatalog.species(id: "birdnet-v3:BN07155"))
        XCTAssertEqual(bird.id, "birdnet-v3:BN07155")
        XCTAssertEqual(SpeciesMediaRole.classic.assetName(for: bird), "birdnet-v3-BN07155-primary")
        XCTAssertEqual(SpeciesMediaRole.flight.assetName(for: bird), "birdnet-v3-BN07155-flight")
        XCTAssertEqual(SpeciesMediaRole.classic.assetName(for: MockSpeciesRepository.kingfisher), "sample-alcedo-atthis-primary")
    }
    func testCurrentCatalogArtworkKeysAreUnique() {
        let keys = SpeciesGuideCatalog.species.map(\.artworkKey)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertTrue(keys.allSatisfy { !$0.contains(":") })
    }
}

// Transport fixtures never contain a personal key and never contact eBird.
private struct EBirdFixtureKeyStore: EBirdKeyStore {
    var key: String? = "fixture-key"
    func read() throws -> String? { key }
    func save(_ key: String) throws { throw CocoaError(.featureUnsupported) }
    func remove() throws { throw CocoaError(.featureUnsupported) }
}

private struct EBirdFixtureHTTP: EBirdHTTPClient {
    var status = 200
    var body = "[]"
    var cancel = false
    var networkFailure = false
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if cancel { throw CancellationError() }
        if networkFailure { throw URLError(.notConnectedToInternet) }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status,
                                               httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
final class EBirdDiscoverTests: XCTestCase {
    private var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }
    private var query: DiscoverQuery { DiscoverQuery(latitude: 0, longitude: 0, now: now, radiusKilometers: DiscoverQuery.nearbyRadiusKilometers) }
    private var index: EBirdSpeciesIndex {
        EBirdSpeciesIndex(entries: [("eurbla", DiscoverFixtures.catalog[0]), ("gretit", DiscoverFixtures.catalog[1])])
    }
    private var validBody: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)
        return """
        [
          {"speciesCode":"eurbla","sciName":"Turdus merula","obsDt":"\(date) 10:15","lat":0,"lng":0,"subId":"S1","obsValid":true},
          {"speciesCode":"eurbla","sciName":"Turdus merula","obsDt":"\(date)","lat":0,"lng":0,"subId":"S2","obsValid":true},
          {"speciesCode":"gretit","sciName":"Parus major","obsDt":"\(date)","lat":0,"lng":0,"subId":"S3","obsValid":true},
          {"speciesCode":"gretit","sciName":"Parus major","obsDt":"\(date)","lat":1,"lng":1,"subId":"far","obsValid":true},
          {"speciesCode":"unknown","sciName":"Unknown species","obsDt":"\(date)","lat":0,"lng":0,"subId":"unknown","obsValid":true}
        ]
        """
    }
    private func repository(http: EBirdFixtureHTTP = EBirdFixtureHTTP(), key: String? = "fixture-key") -> EBirdDiscoverRepository {
        let index = index
        let now = now
        return EBirdDiscoverRepository(keys: EBirdFixtureKeyStore(key: key), client: http,
                                       index: { index }, now: { now })
    }

    func testRequestUsesDefaultThreeDaysFiveKilometersRecencyAndHeaderOnlyKey() throws {
        let request = try EBirdDiscoverRepository.request(query: query, apiKey: "  fixture-key  ")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-eBirdApiToken"), "fixture-key")
        XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertEqual(request.url?.host, "api.ebird.org")
        XCTAssertEqual(request.url?.path, "/v2/data/obs/geo/recent")
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        let parameters = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        XCTAssertEqual(parameters["dist"], "5.0")
        XCTAssertEqual(parameters["sort"], "date")
        XCTAssertEqual(parameters["back"], "3")
        XCTAssertEqual(parameters["cat"], "species")
        XCTAssertEqual(parameters["includeProvisional"], "false")
        XCTAssertFalse(request.url!.absoluteString.contains("fixture-key"))
        let uuidKey = "00000000-0000-0000-0000-000000000001"
        XCTAssertEqual(try EBirdDiscoverRepository.request(query: query, apiKey: uuidKey)
            .value(forHTTPHeaderField: "X-eBirdApiToken"), uuidKey)
        XCTAssertThrowsError(try EBirdDiscoverRepository.request(query: query, apiKey: "key\r\nInjected: value"))
        let bad = DiscoverQuery(latitude: .nan, longitude: 0, now: now, radiusKilometers: DiscoverQuery.nearbyRadiusKilometers)
        XCTAssertThrowsError(try EBirdDiscoverRepository.request(query: bad, apiKey: "fixture-key"))
    }

    func testLiveInventoryPreservesProviderRecencyStableIDsAndLocalRadius() async throws {
        let dataset = try await repository(http: EBirdFixtureHTTP(body: validBody)).reports(for: query)
        let rows = DiscoverRanking.ranked(dataset.reports, query: query, ordering: dataset.ordering)
        XCTAssertFalse(dataset.isDemo)
        XCTAssertEqual(dataset.ordering, .providerRecency)
        XCTAssertEqual(rows.map(\.species.dutchName), ["Merel", "Koolmees"])
        XCTAssertEqual(rows.map(\.reportCount), [2, 1])
        XCTAssertEqual(rows.first?.id, DiscoverFixtures.catalog[0].id)
        XCTAssertEqual(dataset.reports.count, 4) // Unknown species excluded, radius filtered by shared ranking.
    }

    func testUnknownCodesUseOnlyUnambiguousScientificNamesAndAliases() {
        var bird = DiscoverFixtures.catalog[0]
        bird.aliases = ["Historical binomial"]
        let lookup = EBirdSpeciesIndex(entries: [("eurbla", bird)])
        XCTAssertEqual(lookup.species(code: "newcode", scientificName: "Historical binomial")?.id, bird.id)
        XCTAssertNil(lookup.species(code: "unknown", scientificName: "unknown"))
        var other = DiscoverFixtures.catalog[1]
        other.aliases = ["Historical binomial"]
        let ambiguous = EBirdSpeciesIndex(entries: [("eurbla", bird), ("gretit", other)])
        XCTAssertNil(ambiguous.species(code: "unknown", scientificName: "Historical binomial"))
    }

    func testMissingKeyAuthenticationThrottlingMalformedDataAndOfflineErrors() async {
        do { _ = try await repository(key: nil).reports(for: query); XCTFail("Expected missing key") }
        catch { XCTAssertEqual(error as? DiscoverDataError, .notConfigured) }
        for (http, expected) in [
            (EBirdFixtureHTTP(status: 403), EBirdError.invalidKey),
            (EBirdFixtureHTTP(status: 429), .rateLimited),
            (EBirdFixtureHTTP(status: 500), .unavailable),
            (EBirdFixtureHTTP(body: "not-json"), .invalidResponse),
            (EBirdFixtureHTTP(networkFailure: true), .unavailable)
        ] {
            do { _ = try await repository(http: http).reports(for: query); XCTFail("Expected error") }
            catch { XCTAssertEqual(error as? EBirdError, expected) }
        }
    }

    func testCancellationIsPreservedAndEmptyFeedIsSuccessful() async throws {
        do { _ = try await repository(http: EBirdFixtureHTTP(cancel: true)).reports(for: query); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        let empty = try await repository().reports(for: query)
        XCTAssertTrue(empty.reports.isEmpty)
        XCTAssertTrue(empty.coversRequestedWindow)
        XCTAssertFalse(empty.isDemo)
    }

    func testDateOnlyRecordsAndHistoricalRequestsDoNotInventCoverage() async {
        XCTAssertNotNil(EBirdDiscoverRepository.observationDate("2027-01-15", relativeTo: now))
        XCTAssertNotNil(EBirdDiscoverRepository.observationDate("2027-01-12", relativeTo: now))
        XCTAssertNil(EBirdDiscoverRepository.observationDate("2027-01-11", relativeTo: now))
        XCTAssertNil(EBirdDiscoverRepository.observationDate("bad-date", relativeTo: now))
        XCTAssertNil(EBirdDiscoverRepository.observationDate("2020-01-01", relativeTo: now))
        let historical = DiscoverQuery(latitude: 0, longitude: 0, now: now.addingTimeInterval(-31 * 86400), radiusKilometers: DiscoverQuery.nearbyRadiusKilometers)
        do { _ = try await repository().reports(for: historical); XCTFail("Expected unsupported date") }
        catch { XCTAssertEqual(error as? EBirdError, .unsupportedDate) }
    }
}


final class SpeciesArtworkPagingTests: XCTestCase {
    func testFourSlidesLoopBothWaysWithoutSkippingViews() {
        XCTAssertEqual(SpeciesMediaRole.detailSlides, [.dynamic, .front, .rear, .flight])
        var page = 0
        var sequence: [Int] = []
        for _ in 0..<8 {
            sequence.append(page)
            page = SpeciesArtworkPaging.index(after: page, offset: 1, count: 4)!
        }
        XCTAssertEqual(sequence, [0, 1, 2, 3, 0, 1, 2, 3])
        XCTAssertEqual(SpeciesArtworkPaging.index(after: 0, offset: -1, count: 4), 3)
        XCTAssertEqual(SpeciesArtworkPaging.index(after: 3, offset: 1, count: 4), 0)
        XCTAssertNil(SpeciesArtworkPaging.index(after: 0, offset: 1, count: 0))
    }
}


@MainActor
final class SpeciesDetailLayoutTests: XCTestCase {
    func testTitleUsesRegularVariableWeightInsteadOfBlackDefault() throws {
        let font = SpeciesDetailTitleMetrics.font(size: 34)
        let variation = try XCTUnwrap(CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber])
        XCTAssertEqual(variation[NSNumber(value: 0x77676874)]?.doubleValue, 400)
    }

    func testPortraitAndFlightFitAboveTheNavigationButton() {
        let viewport = CGSize(width: 390, height: 500)
        for original in [CGSize(width: 800, height: 1600), CGSize(width: 1800, height: 700)] {
            let fitted = SpeciesArtworkLayout.size(image: original, viewport: viewport, horizontalBleed: false)
            XCTAssertLessThanOrEqual(fitted.width, viewport.width)
            XCTAssertLessThanOrEqual(fitted.height, viewport.height - 32)
            XCTAssertEqual(fitted.width / fitted.height, original.width / original.height, accuracy: 0.001)
        }
        let dynamic = SpeciesArtworkLayout.size(image: CGSize(width: 1000, height: 1000),
                                                viewport: viewport, horizontalBleed: true)
        XCTAssertLessThanOrEqual(dynamic.height, viewport.height - 32)
        XCTAssertEqual(SpeciesArtworkLayout.size(image: .zero, viewport: viewport, horizontalBleed: true), .zero)
    }

    func testHabitatFitsItsWholeComposition() {
        let viewport = CGSize(width: 390, height: 192)
        let fitted = SpeciesArtworkLayout.size(image: CGSize(width: 1200, height: 700),
                                              viewport: viewport, horizontalBleed: false)
        XCTAssertLessThanOrEqual(fitted.width, viewport.width)
        XCTAssertLessThanOrEqual(fitted.height, 160)
        XCTAssertEqual(fitted.width / fitted.height, 1200.0 / 700, accuracy: 0.001)
    }

    func testEnlargedDynamicsCanBleedHorizontallyAndKeepVerticalClearance() {
        let viewport = CGSize(width: 390, height: 620)
        let image = CGSize(width: 1200, height: 800)
        let normal = SpeciesArtworkLayout.size(image: image, viewport: viewport, horizontalBleed: true)
        for id in ["birdnet-v3:BN03838", "birdnet-v3:BN02626", "sample-turdus-merula"] {
            let zoom = SpeciesArtworkLayout.dynamicMagnification(speciesID: id)
            let enlarged = SpeciesArtworkLayout.size(image: image, viewport: viewport,
                                                     horizontalBleed: true, magnification: zoom)
            XCTAssertGreaterThan(enlarged.width, normal.width)
            XCTAssertGreaterThan(enlarged.width, viewport.width)
            XCTAssertLessThanOrEqual(enlarged.height, viewport.height - 52)
            XCTAssertEqual(enlarged.width / enlarged.height, image.width / image.height, accuracy: 0.001)
        }
        // Magnification never changes the other three diagnostic views.
        XCTAssertEqual(SpeciesArtworkLayout.size(image: image, viewport: viewport, horizontalBleed: false, magnification: 1.9),
                       SpeciesArtworkLayout.size(image: image, viewport: viewport, horizontalBleed: false))
    }
}

private struct SpeciesAudioFixtureRepository: SpeciesAudioRepository {
    let recording: BirdAudioRecording?
    var fails = false
    func recording(for species: Species) async throws -> BirdAudioRecording? {
        if fails { throw URLError(.notConnectedToInternet) }
        return recording
    }
}

@MainActor
private final class SpeciesAudioFixturePlayback: SpeciesAudioPlayback {
    var starts = 0
    var stops = 0
    var failure: (@MainActor @Sendable () -> Void)?
    func startLoop(_ recording: BirdAudioRecording, onFailure: @escaping @MainActor @Sendable () -> Void) throws {
        starts += 1
        failure = onFailure
    }
    func stop() { stops += 1 }
}

@MainActor
final class SpeciesAudioTests: XCTestCase {
    private var bird: Species { MockSpeciesRepository.kingfisher }
    private func response(title: String = "File:Alcedo atthis call.mp3", license: String = "CC BY-SA 4.0",
                          original: String = "https://upload.wikimedia.org/test.mp3", derivative: String? = nil) throws -> Data {
        var media: [String: Any] = ["url": original,
            "descriptionurl": "https://commons.wikimedia.org/wiki/File:Alcedo_atthis_call.mp3",
            "extmetadata": ["Artist": ["value": "<a>Fictional recorder</a>"],
                            "LicenseShortName": ["value": license],
                            "LicenseUrl": ["value": "https://creativecommons.org/licenses/by-sa/4.0/"]]]
        if let derivative { media["derivatives"] = [["type": "audio/mpeg", "src": derivative]] }
        return try JSONSerialization.data(withJSONObject: ["query": ["pages": ["1": [
            "pageid": 1, "index": 1, "title": title, "videoinfo": [media]]]]])
    }
    func testExactSpeciesSupportedFormatAndAttribution() throws {
        let recording = try XCTUnwrap(CommonsSpeciesAudioRepository.decode(response(), for: bird))
        XCTAssertEqual(recording.speciesID, bird.id)
        XCTAssertEqual(recording.artist, "Fictional recorder")
        XCTAssertEqual(recording.license, "CC BY-SA 4.0")
        XCTAssertEqual(recording.playbackURL.host, "upload.wikimedia.org")
        XCTAssertNil(try CommonsSpeciesAudioRepository.decode(response(title: "File:Pica pica call.mp3"), for: bird))
        XCTAssertNil(try CommonsSpeciesAudioRepository.decode(response(title: "File:en-us-Alcedo atthis pronunciation.mp3"), for: bird))
        XCTAssertNil(try CommonsSpeciesAudioRepository.decode(response(license: "Unknown rights"), for: bird))
        XCTAssertNil(try CommonsSpeciesAudioRepository.decode(response(original: "https://untrusted.example/test.mp3"), for: bird))
    }
    func testNumericCommonsBookkeepingDoesNotHideValidAudio() throws {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: response()) as? [String: Any])
        var query = try XCTUnwrap(root["query"] as? [String: Any])
        var pages = try XCTUnwrap(query["pages"] as? [String: Any])
        var page = try XCTUnwrap(pages["1"] as? [String: Any])
        var media = try XCTUnwrap(page["videoinfo"] as? [[String: Any]])
        var attributes = try XCTUnwrap(media[0]["extmetadata"] as? [String: Any])
        attributes["CommonsMetadataExtension"] = ["value": 1.2]
        attributes["UnrelatedFlag"] = ["value": true]
        media[0]["extmetadata"] = attributes
        page["videoinfo"] = media; pages["1"] = page; query["pages"] = pages; root["query"] = query
        let data = try JSONSerialization.data(withJSONObject: root)
        XCTAssertNotNil(try CommonsSpeciesAudioRepository.decode(data, for: bird))
        attributes["Artist"] = ["value": 42]
        media[0]["extmetadata"] = attributes
        page["videoinfo"] = media; pages["1"] = page; query["pages"] = pages; root["query"] = query
        XCTAssertNil(try CommonsSpeciesAudioRepository.decode(JSONSerialization.data(withJSONObject: root), for: bird))
    }

    func testOggNeedsOfficialMP3DerivativeAndDoesNotUseAnotherHost() throws {
        XCTAssertNil(try CommonsSpeciesAudioRepository.decode(response(original: "https://upload.wikimedia.org/test.ogg"), for: bird))
        let data = try response(original: "https://upload.wikimedia.org/test.ogg",
                                derivative: "https://upload.wikimedia.org/test.mp3")
        XCTAssertEqual(try CommonsSpeciesAudioRepository.decode(data, for: bird)?.playbackURL.pathExtension, "mp3")
        XCTAssertNil(try CommonsSpeciesAudioRepository.decode(response(original: "https://upload.wikimedia.org/test.ogg",
            derivative: "https://untrusted.example/test.mp3"), for: bird))
    }
    func testTwoTapsStartThenStopAndLeavingPageStopsAgain() async throws {
        let recording = try XCTUnwrap(CommonsSpeciesAudioRepository.decode(response(), for: bird))
        let player = SpeciesAudioFixturePlayback()
        let model = SpeciesAudioModel(repository: SpeciesAudioFixtureRepository(recording: recording), playback: player)
        await model.prepare(for: bird)
        XCTAssertNotNil(model.recording)
        XCTAssertFalse(model.isPlaying) // Availability lookup must never autoplay.
        model.toggle()
        XCTAssertEqual(player.starts, 1)
        XCTAssertTrue(model.isPlaying)
        model.toggle()
        XCTAssertFalse(model.isPlaying)
        model.toggle()
        XCTAssertTrue(model.isPlaying)
        let count = player.stops
        model.leavePage()
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(player.stops, count + 1)
        player.failure?() // Stale player callbacks cannot revive playback or show an error.
        XCTAssertFalse(model.isPlaying)
        XCTAssertNil(model.playbackError)
    }
    func testMissingOrUnavailableRecordingNeverEnablesPlayback() async {
        for fails in [false, true] {
            let player = SpeciesAudioFixturePlayback()
            let model = SpeciesAudioModel(repository: SpeciesAudioFixtureRepository(recording: nil, fails: fails), playback: player)
            await model.prepare(for: bird)
            model.toggle()
            XCTAssertNil(model.recording)
            XCTAssertFalse(model.isPlaying)
            XCTAssertEqual(player.starts, 0)
        }
    }
}

private actor DelayedSpeciesAudioFixture: SpeciesAudioRepository {
    private var response: CheckedContinuation<BirdAudioRecording?, Never>?
    private var requested: CheckedContinuation<Void, Never>?
    func recording(for species: Species) async throws -> BirdAudioRecording? {
        await withCheckedContinuation { continuation in
            response = continuation
            requested?.resume()
            requested = nil
        }
    }
    func waitForRequest() async {
        if response != nil { return }
        await withCheckedContinuation { requested = $0 }
    }
    func finish(_ recording: BirdAudioRecording?) {
        response?.resume(returning: recording)
        response = nil
    }
}

extension SpeciesAudioTests {
    func testLeavingDuringLookupIgnoresLateAvailability() async throws {
        let recording = try XCTUnwrap(CommonsSpeciesAudioRepository.decode(response(), for: bird))
        let repository = DelayedSpeciesAudioFixture()
        let player = SpeciesAudioFixturePlayback()
        let model = SpeciesAudioModel(repository: repository, playback: player)
        let bird = self.bird
        let pending = Task { await model.prepare(for: bird) }
        await repository.waitForRequest()
        model.leavePage()
        await repository.finish(recording)
        await pending.value
        XCTAssertNil(model.recording)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(player.starts, 0)
    }

    func testCurrentPlaybackFailureStopsLoopAndShowsError() async throws {
        let recording = try XCTUnwrap(CommonsSpeciesAudioRepository.decode(response(), for: bird))
        let player = SpeciesAudioFixturePlayback()
        let model = SpeciesAudioModel(repository: SpeciesAudioFixtureRepository(recording: recording), playback: player)
        await model.prepare(for: bird)
        model.toggle()
        player.failure?()
        XCTAssertFalse(model.isPlaying)
        XCTAssertNotNil(model.playbackError)
    }
}

@MainActor
final class SpeciesRangeLoadingTests: XCTestCase {
    private func fixture() throws -> Data {
        let ring = [[0.0,0],[4,0],[4,4],[0,4],[0,0]]
        let hole = [[1.0,1],[2,1],[2,2],[1,2],[1,1]]
        return try JSONSerialization.data(withJSONObject: [
            "type": "FeatureCollection", "providerID": "birdlife-datazone", "speciesID": "test:bird",
            "source": "Fictional fixture", "license": "Test only", "citation": "Fixture author", "version": "2025.2",
            "features": [
                ["type": "Feature", "properties": ["presence": 1,"origin": 1,"seasonal": 1],
                 "geometry": ["type": "Polygon", "coordinates": [ring, hole]]],
                ["type": "Feature", "properties": ["presence": 1,"origin": 3,"seasonal": 3],
                 "geometry": ["type": "MultiPolygon", "coordinates": [[ring]]]],
                ["type": "Feature", "properties": ["presence": 5,"origin": 1,"seasonal": 1],
                 "geometry": ["type": "Polygon", "coordinates": [ring]]]
            ]])
    }
    private func makeBundle() throws -> (URL, Bundle, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        let ranges = root.appendingPathComponent("PrivateBirdLifeRanges")
        try FileManager.default.createDirectory(at: ranges, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "test.range-loading"], format: .xml, options: 0)
        try plist.write(to: root.appendingPathComponent("Info.plist"))
        let source: [String: Any] = ["providerID": "birdlife-datazone", "name": "BirdLife fixture",
            "homepage": "https://datazone.birdlife.org/", "requestURL": "https://datazone.birdlife.org/request",
            "termsURL": "https://datazone.birdlife.org/terms", "access": "approvedAwaitingFiles"]
        try JSONSerialization.data(withJSONObject: source).write(to: root.appendingPathComponent("SpeciesRangeSource.json"))
        let data = try fixture()
        let file = ranges.appendingPathComponent("test-bird-range.geojson")
        try data.write(to: file)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let manifest: [String: Any] = ["formatVersion": 1, "providerID": "birdlife-datazone", "version": "2025.2",
            "citation": "Fixture author", "license": "Test only",
            "files": ["test:bird": ["file": file.lastPathComponent, "sha256": digest]]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: ranges.appendingPathComponent("manifest.json"))
        return (root, try XCTUnwrap(Bundle(url: root)), file)
    }
    func testBackgroundSnapshotPreservesHolesSeasonOriginAndCurrentRangeFilter() throws {
        let snapshot = try SpeciesRangeSnapshot.decode(fixture())
        XCTAssertEqual(snapshot.polygons.count, 2)
        XCTAssertEqual(snapshot.polygons[0].rings.count, 2)
        XCTAssertEqual(snapshot.polygons[1].season, 3)
        XCTAssertEqual(snapshot.polygons[1].origin, 3)
        XCTAssertEqual(snapshot.coordinateCount, 15)
        XCTAssertThrowsError(try SpeciesRangeSnapshot.decode(fixture(), expectedSpeciesID: "wrong"))
    }
    func testBinaryCacheRoundTripPreservesHolesCoordinatesAndRejectsDamage() throws {
        let original = try SpeciesRangeSnapshot.decode(fixture())
        let bytes = SpeciesRangeBinaryCache.encode(original)
        let restored = try SpeciesRangeBinaryCache.decode(bytes)
        XCTAssertEqual(restored.coordinateCount, original.coordinateCount)
        XCTAssertEqual(restored.attribution, original.attribution)
        XCTAssertEqual(restored.polygons[0].rings.count, 2)
        XCTAssertEqual(restored.polygons[1].season, 3)
        XCTAssertEqual(restored.polygons[1].origin, 3)
        XCTAssertEqual(restored.polygons[0].rings[1].map(\.latitude), original.polygons[0].rings[1].map(\.latitude))
        var damaged = bytes; damaged[20] ^= 1
        XCTAssertThrowsError(try SpeciesRangeBinaryCache.decode(damaged))
        XCTAssertThrowsError(try SpeciesRangeBinaryCache.decode(Data(bytes.prefix(30))))
    }
    func testNewLoaderUsesValidatedDiskCacheWithoutReadingSourceAgain() async throws {
        let (root, bundle, file) = try makeBundle()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try Data(contentsOf: file)
        let digest = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
        let cache = root.appendingPathComponent("Cache")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try SpeciesRangeBinaryCache.encode(SpeciesRangeSnapshot.decode(source)).write(to: cache.appendingPathComponent(digest + ".rangebin"))
        try FileManager.default.removeItem(at: file)
        let loader = SpeciesRangeDataLoader(bundle: bundle, cacheDirectory: cache)
        let snapshot = try await loader.load(speciesID: "test:bird")
        XCTAssertEqual(snapshot.polygons.count, 2); XCTAssertEqual(snapshot.coordinateCount, 15)
    }
    func testNativeOverlayCountDependsOnStylesNotPolygonCount() throws {
        let coordinates = [CLLocationCoordinate2D(latitude: 0, longitude: 0), CLLocationCoordinate2D(latitude: 0, longitude: 1),
                           CLLocationCoordinate2D(latitude: 1, longitude: 1), CLLocationCoordinate2D(latitude: 0, longitude: 0)]
        let polygon = coordinates.withUnsafeBufferPointer { MKPolygon(coordinates: $0.baseAddress!, count: $0.count) }
        let areas = (0..<1000).map { SpeciesRangeArea(polygon: polygon, season: $0 < 500 ? .resident : .nonBreeding, origin: 1) }
        let dataset = SpeciesRangeDataset(polygons: areas.map(\.polygon), attribution: "fixture", version: "test", areas: areas)
        let groups = NativeSpeciesRangeMap.groupedOverlays(dataset)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.reduce(0) { $0 + $1.overlay.polygons.count }, 1000)
    }
    func testBackgroundLoaderReusesImmutableSnapshotWithoutReadingFilesAgain() async throws {
        let (root, bundle, file) = try makeBundle()
        defer { try? FileManager.default.removeItem(at: root) }
        let loader = SpeciesRangeDataLoader(bundle: bundle)
        let first = try await loader.load(speciesID: "test:bird")
        try FileManager.default.removeItem(at: file)
        let second = try await loader.load(speciesID: "test:bird")
        XCTAssertEqual(first.coordinateCount, second.coordinateCount)
        XCTAssertEqual(second.polygons.count, 2)
    }
    func testFailedHashIsNotCachedAndValidReplacementCanLoad() async throws {
        let (root, bundle, file) = try makeBundle()
        defer { try? FileManager.default.removeItem(at: root) }
        let loader = SpeciesRangeDataLoader(bundle: bundle)
        try Data("corrupt".utf8).write(to: file)
        do { _ = try await loader.load(speciesID: "test:bird"); XCTFail("Expected hash rejection") }
        catch { guard case RangeDataError.invalid = error else { return XCTFail("Wrong error: \(error)") } }
        try fixture().write(to: file)
        let loaded = try await loader.load(speciesID: "test:bird")
        XCTAssertEqual(loaded.polygons.count, 2)
    }
}

final class ArtworkPaperBackdropTests: XCTestCase {
    func testOnlyEdgeConnectedPaperChangesAndEnclosedWhiteAndAlphaSurvive() {
        let width = 7, height = 7
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<(width * height) {
            let paper = index % width == 0 || index % width == width - 1 || index / width == 0 || index / width == height - 1
            let color: [UInt8] = paper ? [245, 241, 232, 255] : [30, 40, 50, 255]
            pixels.replaceSubrange((index * 4)..<(index * 4 + 4), with: color)
        }
        let center = (3 * width + 3) * 4
        pixels.replaceSubrange(center..<(center + 4), with: [245, 241, 232, 255])
        let transparent = (2 * width + 2) * 4
        pixels.replaceSubrange(transparent..<(transparent + 4), with: [0, 0, 0, 0])
        ArtworkPaperBackdrop.normalize(&pixels, width: width, height: height)
        XCTAssertEqual(Array(pixels[0..<4]), [245, 242, 235, 255])
        XCTAssertEqual(Array(pixels[center..<(center + 4)]), [245, 241, 232, 255])
        XCTAssertEqual(Array(pixels[transparent..<(transparent + 4)]), [0, 0, 0, 0])
        XCTAssertEqual(Array(pixels[(width + 1) * 4..<(width + 2) * 4]), [30, 40, 50, 255])
    }
}

@MainActor
final class SupplementarySpeciesAudioTests: XCTestCase {
    private var bird: Species { MockSpeciesRepository.kingfisher }
    private func fixture(taxon: String = "Alcedo atthis", license: String = "cc-by",
                         file: String = "https://static.inaturalist.org/sounds/1.mp3", hidden: Bool = false,
                         grade: String = "research") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["results": [[
            "id": 7, "quality_grade": grade,
            "taxon": ["name": taxon, "rank": "species", "is_active": true],
            "user": ["login": "fixture-author"],
            "sounds": [["id": 1, "license_code": license, "file_url": file,
                        "file_content_type": "audio/mpeg", "hidden": hidden]]]]])
    }
    func testSupplementarySoundRequiresExactTaxonSoundLicenseAndTrustedPlayableURL() throws {
        let recording = try XCTUnwrap(INaturalistSpeciesAudioRepository.decode(fixture(), for: bird))
        XCTAssertEqual(recording.artist, "fixture-author")
        XCTAssertEqual(recording.license, "CC BY 4.0")
        XCTAssertEqual(recording.sourceURL.absoluteString, "https://www.inaturalist.org/observations/7")
        XCTAssertNil(try INaturalistSpeciesAudioRepository.decode(fixture(taxon: "Pica pica"), for: bird))
        XCTAssertNil(try INaturalistSpeciesAudioRepository.decode(fixture(license: "reserved"), for: bird))
        XCTAssertNil(try INaturalistSpeciesAudioRepository.decode(fixture(hidden: true), for: bird))
        XCTAssertNil(try INaturalistSpeciesAudioRepository.decode(fixture(grade: "casual"), for: bird))
        XCTAssertNil(try INaturalistSpeciesAudioRepository.decode(fixture(file: "https://untrusted.example/1.mp3"), for: bird))
        XCTAssertNil(try INaturalistSpeciesAudioRepository.decode(fixture(file: "https://static.inaturalist.org/sounds/1.ogg"), for: bird))
    }
    func testFallbackWorksAfterEmptyOrFailedPrimaryAndDoesNotReplacePrimary() async throws {
        let recording = try XCTUnwrap(INaturalistSpeciesAudioRepository.decode(fixture(), for: bird))
        let empty = SpeciesAudioFixtureRepository(recording: nil)
        let found = SpeciesAudioFixtureRepository(recording: recording)
        let failed = SpeciesAudioFixtureRepository(recording: nil, fails: true)
        for primary in [empty, failed] {
            let service = SupplementedSpeciesAudioRepository(primary: primary, secondary: found)
            let actual = try await service.recording(for: bird)
            XCTAssertEqual(actual?.id, recording.id)
        }
        let preferred = SupplementedSpeciesAudioRepository(primary: found, secondary: failed)
        let actual = try await preferred.recording(for: bird)
        XCTAssertEqual(actual?.id, recording.id)
        do {
            _ = try await SupplementedSpeciesAudioRepository(primary: failed, secondary: empty).recording(for: bird)
            XCTFail("A network error must not turn into a cached absence")
        } catch { XCTAssertTrue(error is URLError) }
    }
}

private struct FailingGoalUpdatePersistence: ObservationPersistence {
    let goal: BirdGoal
    func load() throws -> [Observation] { [] }
    func loadGoals() throws -> [BirdGoal] { [goal] }
    func save(_ observations: [Observation]) throws { throw CocoaError(.fileWriteNoPermission) }
    func save(_ observations: [Observation], sessions: [BirdSession], goals: [BirdGoal]) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
}

@MainActor
final class SessionFlowRevisionTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 10000)
    private func log(_ species: String, at date: Date, id: UUID = UUID()) -> Observation {
        var record = Observation(speciesID: species, taxonomyVersion: "test", observedAt: date,
            locationName: "Test", count: 1, notes: "", status: .confirmed)
        record.id = id
        return record
    }
    func testLifersUseChronologyNotArrayOrderAndTiesHaveOneWinner() {
        let early = log("a", at: start)
        let later = log("a", at: start.addingTimeInterval(10))
        let different = log("b", at: start)
        let tie = log("a", at: start)
        let ids = SessionStats.liferIDs(in: [later, different, early, tie])
        XCTAssertEqual(ids.count, 2); XCTAssertFalse(ids.contains(later.id)); XCTAssertTrue(ids.contains(different.id))
        XCTAssertEqual(ids, SessionStats.liferIDs(in: [tie, early, different, later]))
        XCTAssertEqual(SessionStats.liferIDs(in: [later]), [later.id])
    }
    func testCompactDurationAndBothSortOptions() {
        let session = BirdSession(locationName: "Test", latitude: 51, longitude: 4, countryCode: "BE",
            startedAt: start, endedAt: start.addingTimeInterval(8040), isLive: false)
        XCTAssertEqual(SessionStats.duration(session), "2u14")
        let a = log(MockSpeciesRepository.kingfisher.id, at: start)
        let b = log("sample-turdus-merula", at: start.addingTimeInterval(1))
        XCTAssertEqual(SessionStats.sorted([a,b], by: .latest).map(\.id), [b.id,a.id])
        XCTAssertEqual(SessionStats.sorted([b,a], by: .alphabetical).map(\.id), [a.id,b.id])
    }
    func testRemovingLiveLogAllowsReaddingAndCompletedEditingPreservesOtherRecords() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ObservationStore(persistence: JSONObservationPersistence(url: url))
        let standalone = log("outside", at: start); try store.save(standalone)
        let session = BirdSession(locationName: "Test", latitude: 51, longitude: 4, countryCode: "BE",
            startedAt: start, endedAt: nil, isLive: true)
        try store.startSession(session)
        let point = SessionLogLocation(latitude: 51, longitude: 4, name: "Actual", countryCode: "BE")
        let bird = MockSpeciesRepository.kingfisher
        try store.logLive(bird, sessionID: session.id, at: start.addingTimeInterval(5), location: point)
        XCTAssertThrowsError(try store.logLive(bird, sessionID: session.id, at: start.addingTimeInterval(6), location: point))
        let record = try XCTUnwrap(store.observations(in: session).first)
        XCTAssertThrowsError(try store.removeLiveObservation(id: standalone.id, sessionID: session.id))
        try store.removeLiveObservation(id: record.id, sessionID: session.id)
        XCTAssertEqual(store.observations, [standalone])
        try store.logLive(bird, sessionID: session.id, at: start.addingTimeInterval(7), location: point)
        try store.finishSession(at: start.addingTimeInterval(20))
        var completed = try XCTUnwrap(store.completedSessions.first)
        let expected = store.observations(in: completed)
        completed.locationName = "Edited"
        try store.updateCompletedSession(completed, logs: expected, expectedLogs: expected)
        XCTAssertEqual(store.completedSessions.first?.locationName, "Edited")
        XCTAssertEqual(store.observations(in: completed), expected)
        XCTAssertTrue(store.observations.contains(standalone))
        var duplicate = expected[0]; duplicate.id = UUID()
        XCTAssertThrowsError(try store.updateCompletedSession(completed, logs: expected + [duplicate], expectedLogs: expected))
        try store.updateCompletedSession(completed, logs: [], expectedLogs: expected)
        XCTAssertThrowsError(try store.updateCompletedSession(completed, logs: expected, expectedLogs: expected))
        let restored = ObservationStore(persistence: JSONObservationPersistence(url: url))
        XCTAssertEqual(restored.observations, [standalone]); XCTAssertEqual(restored.completedSessions.first?.locationName, "Edited")
    }
}

@MainActor
final class AudioCapturePipelineTests: XCTestCase {
    func testWatchdogToleratesStartupAndDetectsMissingOrStalledSamples() {
        let start = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(AudioCaptureHealth.isStalled(startedAt: nil, lastAudioAt: nil, now: start))
        XCTAssertFalse(AudioCaptureHealth.isStalled(startedAt: start, lastAudioAt: nil, now: start.addingTimeInterval(4)))
        XCTAssertTrue(AudioCaptureHealth.isStalled(startedAt: start, lastAudioAt: nil, now: start.addingTimeInterval(5)))
        XCTAssertFalse(AudioCaptureHealth.isStalled(startedAt: start, lastAudioAt: start.addingTimeInterval(4), now: start.addingTimeInterval(6)))
    }
    func testBackgroundProcessorBuildsThreeSecondWindowInMemory() async throws {
        let processor = AudioCaptureProcessor()
        let samples = (0..<32000).map { Float(sin(2 * Double.pi * 1000 * Double($0) / 32000)) * 0.1 }
        let start = Date()
        var window: LiveAudioWindow?
        for second in 0..<3 {
            let update = try await processor.consume(CapturedAudioChunk(samples: samples, sampleRate: 32000,
                endedAt: start.addingTimeInterval(Double(second))))
            XCTAssertEqual(update.column?.count, 32)
            window = update.window
        }
        await processor.close()
        XCTAssertEqual(window?.samples.count, 96000)
    }
}

final class SoundCandidateConfirmationTests: XCTestCase {
    private var bird: Species { MockSpeciesRepository.kingfisher }
    func testWeakSupportedMatchesAreRetainedAtTheirOriginalScore() {
        var filter = SoundCandidateConfirmation()
        let weak = IdentificationCandidate(species: bird, score: 0.4)
        XCTAssertTrue(filter.accept([weak]).isEmpty)
        let confirmed = filter.accept([weak])
        XCTAssertEqual(confirmed.map(\.id), [bird.id])
        XCTAssertEqual(confirmed.first?.score, 0.4)
    }
    func testStrongMatchIsImmediateAndIsolatedWeakOrInvalidScoresAreNotShown() {
        var filter = SoundCandidateConfirmation()
        XCTAssertEqual(filter.accept([IdentificationCandidate(species: bird, score: 0.85)]).count, 1)
        filter = SoundCandidateConfirmation()
        let weak = IdentificationCandidate(species: bird, score: 0.4)
        XCTAssertTrue(filter.accept([weak]).isEmpty)
        for _ in 0..<3 { XCTAssertTrue(filter.accept([]).isEmpty) }
        XCTAssertTrue(filter.accept([weak]).isEmpty)
        for score in [0.1, 0.22, -1, 1.1, Double.nan, Double.infinity] {
            XCTAssertTrue(filter.accept([IdentificationCandidate(species: bird, score: score)]).isEmpty)
        }
    }
}

private struct ImmediateLocationFixture: CurrentLocationService {
    let fix: AppLocationFix
    @MainActor func current(policy: AppLocationPolicy) async throws -> AppLocationFix { fix }
}
@MainActor
final class FastLocationRevisionTests: XCTestCase {
    func testCachedFixPoliciesRejectStaleInaccurateOrInvalidPositions() {
        let now = Date(timeIntervalSince1970: 1000)
        let old = AppLocationFix(latitude: 51, longitude: 4, accuracy: 30, timestamp: now.addingTimeInterval(-20))
        XCTAssertTrue(old.isUsable(maxAge: AppLocationPolicy.observation.maxAge, maxAccuracy: 150, now: now))
        XCTAssertFalse(old.isUsable(maxAge: AppLocationPolicy.liveLog.maxAge, maxAccuracy: 100, now: now))
        let coarse = AppLocationFix(latitude: 51, longitude: 4, accuracy: 400, timestamp: now)
        XCTAssertTrue(coarse.isUsable(maxAge: 60, maxAccuracy: AppLocationPolicy.browsing.maxAccuracy, now: now))
        XCTAssertFalse(coarse.isUsable(maxAge: 30, maxAccuracy: AppLocationPolicy.observation.maxAccuracy, now: now))
        XCTAssertFalse(AppLocationFix(latitude: .nan, longitude: 4, accuracy: 1, timestamp: now).isUsable(maxAge: 60, maxAccuracy: 500, now: now))
    }
    func testLocationModelUsesSharedServiceAndNamingWithoutHardwareCallbacks() async {
        let fix = AppLocationFix(latitude: 51, longitude: 4, accuracy: 10, timestamp: Date())
        let model = ObservationLocationModel(namingService: TestPlaceNamingService(), currentLocation: ImmediateLocationFixture(fix: fix))
        await model.useCurrentLocation().value
        XCTAssertEqual(model.latitude, 51); XCTAssertEqual(model.longitude, 4)
        XCTAssertEqual(model.locationName, "Voorbeeldpark"); XCTAssertTrue(model.canSave)
    }
    func testFamilyDisplayUsesFriendlyLabelsWithoutChangingIdentity() {
        let family = BirdFamily.displayFamily(id: "Ardeidae", englishName: "Herons, Egrets, and Bitterns")
        XCTAssertEqual(family.id, "Ardeidae"); XCTAssertEqual(family.dutchName, "Reigers")
        let rare = BirdFamily.displayFamily(id: "Rareidae", englishName: "Friendly birds")
        XCTAssertEqual(rare.dutchName, "Friendly birds")
    }
}

final class IdentificationRefinementTests: XCTestCase {
    func testRepeatedVeryWeakAudioDoesNotBecomeAConfirmedSpecies() {
        var filter = SoundCandidateConfirmation()
        let candidate = IdentificationCandidate(species: MockSpeciesRepository.kingfisher, score: 0.29)
        for _ in 0..<10 { XCTAssertTrue(filter.accept([candidate]).isEmpty) }
    }
    func testPhotoCandidatesMustStayNearBestVisualMatch() {
        let results = PhotoSimilarity.accepted([("best", 0.8), ("close", 0.77), ("distant", 0.65)])
        XCTAssertEqual(results.map(\.0), ["best", "close"])
    }
    func testGeographicContextPreservesHolesAndDateLineCrossings() {
        func ring(_ points: [(Double, Double)]) -> [SpeciesRangeSnapshot.Point] {
            points.map { .init(longitude: $0.0, latitude: $0.1) }
        }
        let exterior = ring([(0,0),(4,0),(4,4),(0,4),(0,0)])
        let hole = ring([(1,1),(2,1),(2,2),(1,2),(1,1)])
        let local = SpeciesRangeSnapshot(polygons: [.init(rings: [exterior, hole], season: 1, origin: 1)], attribution: "fixture", version: "test")
        XCTAssertTrue(PhotoRangeContext.contains(local, latitude: 3, longitude: 3))
        XCTAssertFalse(PhotoRangeContext.contains(local, latitude: 1.5, longitude: 1.5))
        XCTAssertFalse(PhotoRangeContext.contains(local, latitude: 6, longitude: 6))
        let dateLine = ring([(170,0),(-170,0),(-170,10),(170,10),(170,0)])
        let remote = SpeciesRangeSnapshot(polygons: [.init(rings: [dateLine], season: 1, origin: 1)], attribution: "fixture", version: "test")
        XCTAssertTrue(PhotoRangeContext.contains(remote, latitude: 5, longitude: 179))
        XCTAssertTrue(PhotoRangeContext.contains(remote, latitude: 5, longitude: -179))
        XCTAssertFalse(PhotoRangeContext.contains(remote, latitude: 5, longitude: 0))
    }
}

final class MenuRevealGeometryTests: XCTestCase {
    func testCompletedCircleCoversScreenOutsideTheMaskSafeArea() {
        let screen = CGRect(x: 0, y: 0, width: 393, height: 852)
        let frame = CGRect(x: 0, y: 59, width: 393, height: 700)
        let button = CGPoint(x: 196.5, y: 759)
        let circle = MenuRevealGeometry.circle(globalOrigin: button, maskFrame: frame, progress: 1, coverageFrame: screen)
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: 393, y: 0), CGPoint(x: 0, y: 852), CGPoint(x: 393, y: 852)] {
            let distance = hypot(corner.x - button.x, corner.y - button.y)
            XCTAssertGreaterThanOrEqual(circle.width / 2 - distance, 31.99)
        }
        XCTAssertEqual(circle.midY + frame.minY, button.y, accuracy: 0.001)
    }

    func testCircleStaysCenteredOnButtonAcrossSafeAreaFrames() {
        let button = CGPoint(x: 196.5, y: 759)
        for frame in [CGRect(x: 0, y: 0, width: 393, height: 852), CGRect(x: 0, y: 59, width: 393, height: 700)] {
            for progress: CGFloat in [0, 0.2, 0.5, 1] {
                let circle = MenuRevealGeometry.circle(globalOrigin: button, maskFrame: frame, progress: progress)
                XCTAssertEqual(circle.width, circle.height, accuracy: 0.001)
                XCTAssertEqual(circle.midX + frame.minX, button.x, accuracy: 0.001)
                XCTAssertEqual(circle.midY + frame.minY, button.y, accuracy: 0.001)
                if progress == 1 {
                    for corner in [CGPoint(x: 0, y: 0), CGPoint(x: frame.width, y: 0), CGPoint(x: 0, y: frame.height), CGPoint(x: frame.width, y: frame.height)] {
                        XCTAssertLessThanOrEqual(hypot(corner.x - circle.midX, corner.y - circle.midY), circle.width / 2 + 0.001)
                    }
                }
            }
        }
    }
}

@MainActor
final class BackupSafetyTests: XCTestCase {
    private func archive() -> BirdingArchive {
        let session = BirdSession(locationName: "Voorbeeldpark", latitude: 51, longitude: 4, countryCode: "BE",
                                  startedAt: Date(timeIntervalSince1970: 1000), endedAt: Date(timeIntervalSince1970: 2000), isLive: false)
        let bird = MockSpeciesRepository.kingfisher
        var log = Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion,
                              observedAt: Date(timeIntervalSince1970: 1500), locationName: session.locationName,
                              count: 2, notes: "Mijn notitie", status: .confirmed)
        log.latitude = session.latitude; log.longitude = session.longitude; log.countryCode = "BE"; log.sessionID = session.id
        var goal = BirdGoal(name: "Voorbeeld", speciesIDs: [bird.id]); goal.favoriteSpeciesID = bird.id
        return BirdingArchive(observations: [log], sessions: [session], goals: [goal])
    }
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    func testFullArchiveRoundTripPreservesSessionsGoalsAndStableIDs() throws {
        let original = archive()
        let bytes = try BackupCodec.encode(payload: JSONEncoder().encode(original), date: Date(timeIntervalSince1970: 3000))
        let decoded = try BackupCodec.decode(bytes)
        XCTAssertEqual(decoded.archive, original)
        XCTAssertEqual(decoded.date, Date(timeIntervalSince1970: 3000))
        let document = try JSONDecoder().decode(BackupCodec.Document.self, from: bytes)
        let damaged = BackupCodec.Document(format: document.format, version: document.version, createdAt: document.createdAt,
                                          payload: document.payload + Data([0]), sha256: document.sha256)
        XCTAssertThrowsError(try BackupCodec.decode(JSONEncoder().encode(damaged)))
    }
    func testEarlierFullAndStandaloneObservationExportsRemainReadable() throws {
        let original = archive()
        XCTAssertEqual(try BackupCodec.decode(JSONEncoder().encode(original)).archive, original)
        var standalone = original.observations[0]; standalone.sessionID = nil
        let legacy = try BackupCodec.decode(JSONEncoder().encode([standalone]))
        XCTAssertEqual(legacy.archive.observations, [standalone]); XCTAssertTrue(legacy.archive.sessions.isEmpty)
        XCTAssertNil(legacy.date)
    }
    func testInvalidFutureDuplicateAndOrphanArchivesAreRejected() throws {
        var future = archive(); future.version = 999
        XCTAssertThrowsError(try BackupCodec.encode(payload: JSONEncoder().encode(future)))
        var duplicate = archive(); let repeatedGoal = duplicate.goals![0]; duplicate.goals?.append(repeatedGoal)
        XCTAssertThrowsError(try BackupCodec.validate(duplicate))
        var orphan = archive(); orphan.sessions = []
        XCTAssertThrowsError(try BackupCodec.validate(orphan))
        XCTAssertThrowsError(try BackupCodec.decode(Data("broken".utf8)))
    }
    func testRestorePreservesPreviousFileAndRejectsStalePreview() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("observations.json")
        let persistence = JSONObservationPersistence(url: file)
        let before = archive(), incoming = archive()
        try persistence.save(before.observations, sessions: before.sessions, goals: before.goals ?? [])
        let store = ObservationStore(persistence: persistence)
        let oldRevision = store.revision
        let originalBytes = try Data(contentsOf: file)
        try store.restoreArchive(incoming, expectedRevision: oldRevision)
        let reloaded = ObservationStore(persistence: persistence)
        XCTAssertEqual(reloaded.observations, incoming.observations)
        XCTAssertEqual(reloaded.sessions, incoming.sessions); XCTAssertEqual(reloaded.goals, incoming.goals ?? [])
        let safety = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("RecoveryCopies"), includingPropertiesForKeys: nil)
        XCTAssertEqual(safety.count, 1); XCTAssertEqual(try Data(contentsOf: XCTUnwrap(safety.first)), originalBytes)
        XCTAssertThrowsError(try store.restoreArchive(before, expectedRevision: oldRevision))
        XCTAssertEqual(store.observations, incoming.observations)
    }
    func testUnreadableLocalArchiveCanBeRecoveredWithoutLosingOriginalBytes() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("observations.json"), damaged = Data("damaged file".utf8)
        try damaged.write(to: file)
        let store = ObservationStore(persistence: JSONObservationPersistence(url: file))
        XCTAssertNotNil(store.loadError)
        let incoming = archive()
        try store.restoreArchive(incoming, expectedRevision: store.revision)
        XCTAssertNil(store.loadError); XCTAssertEqual(store.observations, incoming.observations)
        let safety = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("RecoveryCopies"), includingPropertiesForKeys: nil)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(safety.first)), damaged)
    }
    func testFailedRestoreWriteDoesNotPublishOrAdvanceRevision() throws {
        let persistence = FailingRestorePersistence(original: archive())
        let store = ObservationStore(persistence: persistence), revision = store.revision
        XCTAssertThrowsError(try store.restoreArchive(archive(), expectedRevision: revision))
        XCTAssertEqual(store.revision, revision); XCTAssertEqual(store.observations, persistence.original.observations)
    }
    func testCoordinatedBackupWritesDistinctVerifiedVersions() async throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let payload = try JSONEncoder().encode(archive()), files = BackupFiles()
        let first = try await files.write(payload: payload, directory: directory, reason: "test")
        let second = try await files.write(payload: payload, directory: directory, reason: "test")
        XCTAssertNotEqual(first, second)
        let restored = try await files.read(first)
        XCTAssertEqual(try BackupCodec.decode(Data(contentsOf: second)).archive, restored.0)
        XCTAssertEqual(try BackupCodec.decode(Data(contentsOf: first)).archive, restored.0)
    }
    func testFailedBackupKeepsLastSuccessfulTimestamp() async throws {
        let name = "BackupSafetyTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data([0]), forKey: "backup.folder")
        defaults.set(1000.0, forKey: "backup.lastSuccess")
        let controller = BackupController(defaults: defaults)
        let store = ObservationStore(persistence: PreviewObservationPersistence())
        await controller.save(store: store)
        XCTAssertEqual(controller.lastSuccess, Date(timeIntervalSince1970: 1000))
        XCTAssertNotNil(controller.message); XCTAssertFalse(controller.isBusy)
    }
}

private struct FailingRestorePersistence: ObservationPersistence {
    let original: BirdingArchive
    func load() throws -> [Observation] { original.observations }
    func loadSessions() throws -> [BirdSession] { original.sessions }
    func loadGoals() throws -> [BirdGoal] { original.goals ?? [] }
    func preserveBeforeRestore() throws {}
    func save(_ observations: [Observation]) throws { throw CocoaError(.fileWriteOutOfSpace) }
    func save(_ observations: [Observation], sessions: [BirdSession], goals: [BirdGoal]) throws { throw CocoaError(.fileWriteOutOfSpace) }
}

@MainActor
final class DiscoverFeedbackRegressionTests: XCTestCase {
    func testSearchNormalizesPunctuationAndRepeatedWhitespace() {
        let bird = Species(id: "cetti", taxonomyVersion: "test", dutchName: "Cetti’s zanger",
                           englishName: "Cetti's Warbler", scientificName: "Cettia cetti")
        for term in ["cetti zanger", "cetti's zanger", "CETTI’S   ZANGER", "Cettia\n cetti"] {
            XCTAssertEqual(SpeciesCatalogSearch.results(for: term, in: [bird]).map(\.id), [bird.id])
        }
        XCTAssertTrue(SpeciesCatalogSearch.results(for: "onbestaande soort", in: [bird]).isEmpty)
    }
    func testExtinctSpeciesHiddenButHistoricalIdentityRetained() throws {
        XCTAssertTrue(GuideSpeciesRepository().search("Black Mamo").isEmpty)
        XCTAssertTrue(GuideSpeciesRepository().search("Red Rail").isEmpty)
        let all = try JSONDecoder().decode([WorldSpeciesRecord].self,
            from: Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "WorldSpeciesCatalog", withExtension: "json"))))
        XCTAssertEqual(all.filter(\.isExtinct).count, 151)
        for record in all where record.isExtinct {
            XCTAssertNotNil(SpeciesGuideCatalog.species(id: record.id))
            XCTAssertFalse(SpeciesGuideCatalog.species.contains { $0.id == record.id })
        }
        XCTAssertTrue(all.filter { $0.extinction == "Extinct in the Wild" }.allSatisfy { !$0.isExtinct })
        XCTAssertTrue(all.filter { $0.extinction == "Possibly Extinct" }.allSatisfy { !$0.isExtinct })
        XCTAssertEqual(SpeciesGuideCatalog.species(id: "birdnet-v3:BN09928")?.dutchName, "Zwartkopvlagstaartijsvogel")
        XCTAssertEqual(SpeciesGuideCatalog.species(id: "avilist:93d88f0a")?.dutchName, "Norfolkbrilvogel")
    }
    func testObservationRequestUsesDefaultThreeDaysLargerPagesAndBoundedRadius() throws {
        let query = DiscoverQuery(latitude: 51, longitude: 4, now: Date(timeIntervalSince1970: 1_800_000_000), radiusKilometers: 30)
        let request = try ObservationOrgDiscoverRepository.request(query: query, offset: 1000)
        let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["radius"], "10000")
        XCTAssertEqual(values["days"], "3")
        XCTAssertEqual(values["offset"], "1000")
        XCTAssertEqual(values["end_date"], "2027-01-15")
        XCTAssertEqual(values["limit"], "1000")
        XCTAssertThrowsError(try ObservationOrgDiscoverRepository.request(query: query, offset: -1))
        XCTAssertEqual(DiscoverQuery.validRadius(.nan), 5)
        XCTAssertEqual(DiscoverQuery.validRadius(-5), 1)
        XCTAssertEqual(DiscoverQuery.validRadius(100), 50)
    }
    func testMixedFeedSortsAcrossProvidersAndKeepsLatestSourceLink() throws {
        let bird = MockSpeciesRepository.kingfisher
        let now = Date()
        let ebird = NearbyReport(checklistID: "S123", species: bird, observedAt: now, latitude: 0, longitude: 0,
                                localObservedAt: "2026-11-23 09:00")
        let source = URL(string: "https://observation.org/observation/42/")!
        let observation = NearbyReport(checklistID: "observation:42", species: bird, observedAt: now, latitude: 0, longitude: 0,
                                      observationURL: source, localObservedAt: "2026-11-23 10:00")
        let a = DiscoverDataset(reports: [ebird], attribution: "eBird", isDemo: false, coversRequestedWindow: true)
        let b = DiscoverDataset(reports: [observation], attribution: "Observation.org", isDemo: false, coversRequestedWindow: true)
        let mixed = try CombinedDiscoverRepository.combine(ebird: .success(a), observation: .success(b))
        XCTAssertEqual(mixed.reports.map(\.checklistID), ["observation:42", "S123"])
        let rows = DiscoverRanking.ranked(mixed.reports, query: DiscoverQuery(latitude: 0, longitude: 0, now: now, radiusKilometers: 5), ordering: mixed.ordering)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.observationURL, source)
        let fallback = try CombinedDiscoverRepository.combine(ebird: .success(a), observation: .failure(URLError(.notConnectedToInternet)))
        XCTAssertEqual(fallback.reports.count, 1)
        XCTAssertNotNil(fallback.warning)
        let timeout = try CombinedDiscoverRepository.combine(ebird: .success(a), observation: .failure(URLError(.timedOut)))
        XCTAssertTrue(timeout.warning?.contains("reageert te traag") == true)
        XCTAssertThrowsError(try CombinedDiscoverRepository.combine(ebird: .failure(DiscoverDataError.notConfigured), observation: .failure(URLError(.notConnectedToInternet))))
    }
    func testObservationMissingPointIsSkippedWithoutRejectingOtherRecords() async throws {
        let body = #"{"next":null,"results":[{"id":1,"date":"2026-11-23","species_detail":{"scientific_name":"Alcedo atthis","group":1,"type":"S"},"point":null,"is_certain":true}]}"#
        let bird = MockSpeciesRepository.kingfisher
        let repo = ObservationOrgDiscoverRepository(client: EBirdFixtureHTTP(body: body),
            index: { EBirdSpeciesIndex(entries: [(code: nil, species: bird)]) }, cacheEnabled: false)
        let dataset = try await repo.reports(for: DiscoverQuery(latitude: 0, longitude: 0,
            now: Date(timeIntervalSince1970: 1_795_435_200), radiusKilometers: 5))
        XCTAssertTrue(dataset.reports.isEmpty)
    }
    func testObservationEmptyContinuationRejectsIncompleteFeed() async {
        let repo = ObservationOrgDiscoverRepository(client: EBirdFixtureHTTP(body: #"{"next":"more","results":[]}"#), cacheEnabled: false)
        do {
            _ = try await repo.reports(for: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: 5))
            XCTFail("A partial provider feed must not be presented as complete")
        } catch {
            guard let problem = error as? ObservationOrgError, case .incomplete = problem else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
    func testObservationDuplicateIDsDoNotProduceDuplicateReports() async throws {
        let record = #"{"id":42,"date":"2026-11-23","time":"10:30","species_detail":{"scientific_name":"Alcedo atthis","group":1,"type":"S"},"point":{"coordinates":[0,0]},"is_certain":true,"is_escape":false}"#
        let body = "{\"next\":null,\"results\":[" + record + "," + record + "]}"
        let bird = MockSpeciesRepository.kingfisher
        let repo = ObservationOrgDiscoverRepository(client: EBirdFixtureHTTP(body: body),
            index: { EBirdSpeciesIndex(entries: [(code: nil, species: bird)]) }, cacheEnabled: false)
        let reports = try await repo.reports(for: DiscoverQuery(latitude: 0, longitude: 0, now: Date(timeIntervalSince1970: 1_795_435_200), radiusKilometers: 5))
        XCTAssertEqual(reports.reports.count, 1)
        XCTAssertEqual(reports.reports.first?.checklistID, "observation:42")
    }
}

private actor DiscoverProgressGate {
    private var opened = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private(set) var updates: [DiscoverDataset] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiting.append($0) }
    }
    func release(update: DiscoverDataset? = nil) {
        if let update { updates.append(update) }
        opened = true
        for continuation in waiting { continuation.resume() }
        waiting.removeAll()
    }
}

private struct GatedDiscoverFixture: DiscoverRepository {
    let gate: DiscoverProgressGate
    let dataset: DiscoverDataset
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset {
        try await withTaskCancellationHandler {
            await gate.wait()
            try Task.checkCancellation()
            return dataset
        } onCancel: {
            Task { await gate.release() }
        }
    }
}

private struct ImmediateDiscoverFixture: DiscoverRepository {
    let dataset: DiscoverDataset
    func reports(for query: DiscoverQuery) async throws -> DiscoverDataset { dataset }
}

@MainActor
final class DiscoverProgressTests: XCTestCase {
    func testFastSourcePublishesBeforeSecondSourceCompletes() async throws {
        let gate = DiscoverProgressGate()
        let now = Date()
        let bird = MockSpeciesRepository.kingfisher
        let first = DiscoverDataset(reports: [NearbyReport(checklistID: "S1", species: bird,
            observedAt: now, latitude: 0, longitude: 0, localObservedAt: "2026-11-23 09:00")],
            attribution: "eBird", isDemo: false, coversRequestedWindow: true)
        let second = DiscoverDataset(reports: [NearbyReport(checklistID: "observation:2", species: bird,
            observedAt: now, latitude: 0, longitude: 0, localObservedAt: "2026-11-23 10:00")],
            attribution: "Observation.org", isDemo: false, coversRequestedWindow: true)
        let repo = CombinedDiscoverRepository(ebird: ImmediateDiscoverFixture(dataset: first),
            observation: GatedDiscoverFixture(gate: gate, dataset: second), timeout: .seconds(1))
        // The second source can only finish once an interim result has actually
        // reached the consumer. A timeout releases the gate if this regresses.
        let result = try await repo.reports(for: DiscoverQuery(latitude: 0, longitude: 0, now: now, radiusKilometers: 5)) {
            await gate.release(update: $0)
        }
        let updates = await gate.updates
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.reports.map(\.checklistID), ["S1"])
        XCTAssertEqual(result.reports.map(\.checklistID), ["observation:2", "S1"])
        XCTAssertNil(result.warning)
    }

    func testStalledProvidersStopLoadingWithAnError() async {
        let empty = DiscoverDataset(reports: [], attribution: "test", isDemo: false, coversRequestedWindow: true)
        let repo = CombinedDiscoverRepository(
            ebird: GatedDiscoverFixture(gate: DiscoverProgressGate(), dataset: empty),
            observation: GatedDiscoverFixture(gate: DiscoverProgressGate(), dataset: empty), timeout: .milliseconds(30))
        let model = DiscoverViewModel(repository: repo)
        await model.load(query: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: 5))
        XCTAssertFalse(model.isLoading)
        XCTAssertNotNil(model.message)
        XCTAssertTrue(model.rows.isEmpty)
    }
}

@MainActor
final class DiscoveryAndPhotoContextFeedbackTests: XCTestCase {
    func testDiscoveryPeriodIsSharedByRequestsAndLocalFilter() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let standard = DiscoverQuery(latitude: 0, longitude: 0, now: now, radiusKilometers: 5)
        XCTAssertEqual(standard.daysBack, 3)
        XCTAssertEqual(standard.start, now.addingTimeInterval(-3 * 86400))
        for days in [1, 3, 7, 14] {
            let query = DiscoverQuery(latitude: 0, longitude: 0, now: now, radiusKilometers: 5, daysBack: days)
            let ebird = try EBirdDiscoverRepository.request(query: query, apiKey: "fixture")
            let observation = try ObservationOrgDiscoverRepository.request(query: query, offset: 0)
            func value(_ name: String, in request: URLRequest) -> String? {
                URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
            }
            XCTAssertEqual(value("back", in: ebird), String(days))
            XCTAssertEqual(value("days", in: observation), String(days))
            let bird = MockSpeciesRepository.kingfisher
            let rows = [NearbyReport(checklistID: "inside", species: bird, observedAt: query.start, latitude: 0, longitude: 0),
                        NearbyReport(checklistID: "outside", species: bird, observedAt: query.start.addingTimeInterval(-1), latitude: 0, longitude: 0)]
            XCTAssertEqual(DiscoverRanking.ranked(rows, query: query).first?.reportCount, 1)
        }
        XCTAssertEqual(DiscoverQuery.validLookbackDays(0), 1)
        XCTAssertEqual(DiscoverQuery.validLookbackDays(99), 14)
    }

    func testOnlyAvailableArtworkPagesCanBeVisited() {
        XCTAssertEqual(SpeciesArtworkPaging.slides(available: []), [])
        XCTAssertEqual(SpeciesArtworkPaging.slides(available: [.classic]), [.classic])
        XCTAssertEqual(SpeciesArtworkPaging.slides(available: [.classic, .dynamic]), [.dynamic])
        XCTAssertEqual(SpeciesArtworkPaging.slides(available: [.classic, .front]), [.front])
        XCTAssertEqual(SpeciesArtworkPaging.slides(available: [.classic, .dynamic, .rear]), [.dynamic, .rear])
        XCTAssertNil(SpeciesArtworkPaging.index(after: 0, offset: 1, count: 1))
        XCTAssertNil(SpeciesArtworkPaging.index(after: 0, offset: -1, count: 1))
        XCTAssertEqual(SpeciesArtworkPaging.index(after: 1, offset: 1, count: 2), 0)
    }

    func testNorthernRavenIsPlausibleInBelgiumWithoutPromotingForeignRavens() throws {
        let raven = try XCTUnwrap(SpeciesGuideCatalog.species.first { $0.scientificName == "Corvus corax" })
        let foreign = try XCTUnwrap(SpeciesGuideCatalog.species.first { $0.scientificName == "Corvus albicollis" })
        XCTAssertTrue(PhotoRegionalContext.isRegular(raven.id, countryCode: "BE"))
        XCTAssertFalse(PhotoRegionalContext.isRegular(foreign.id, countryCode: "BE"))
        XCTAssertFalse(PhotoRegionalContext.isRegular(raven.id, countryCode: "IN"))
        let antwerp = PhotoLocationSelection(latitude: 51.22, longitude: 4.4, name: "Antwerpen", countryCode: "BE")
        XCTAssertEqual(PhotoRangeContext.likelihood(nil, at: antwerp, regularInCountry: true), .likely)
        XCTAssertEqual(PhotoRangeContext.likelihood(nil, at: antwerp, regularInCountry: false), .unknown)
    }

    func testCoarseRangeMarginsAndDateLineDoNotPromoteDistantSpecies() {
        func snapshot(_ points: [(Double, Double)]) -> SpeciesRangeSnapshot {
            SpeciesRangeSnapshot(polygons: [.init(rings: [points.map { .init(longitude: $0.0, latitude: $0.1) }], season: 1, origin: 1)], attribution: "fixture", version: "test")
        }
        let range = snapshot([(0,0), (1,0), (1,1), (0,1), (0,0)])
        XCTAssertEqual(PhotoRangeContext.likelihood(range, at: .init(latitude: 0.5, longitude: 1.1, name: "near"), regularInCountry: false), .likely)
        XCTAssertEqual(PhotoRangeContext.likelihood(range, at: .init(latitude: 0.5, longitude: 5, name: "far"), regularInCountry: false), .unlikely)
        let dateLine = snapshot([(170,0), (-170,0), (-170,10), (170,10), (170,0)])
        XCTAssertEqual(PhotoRangeContext.likelihood(dateLine, at: .init(latitude: 5, longitude: 0, name: "far"), regularInCountry: false), .unlikely)
        XCTAssertEqual(PhotoRangeContext.likelihood(dateLine, at: .init(latitude: 5, longitude: 169.9, name: "near edge"), regularInCountry: false), .likely)
    }
}

@MainActor
final class BirdaImportTests: XCTestCase {
    private let bird = Species(id: "test-bird", taxonomyVersion: "test-v1", dutchName: "Testvogel",
        englishName: "Test bird", scientificName: "Testus birdus", aliases: ["Oldus birdus|Anotherus birdus"])
    private let session = "10000000-0000-0000-0000-000000000000"
    private let one = "20000000-0000-0000-0000-000000000001"
    private let two = "20000000-0000-0000-0000-000000000002"
    private let three = "20000000-0000-0000-0000-000000000003"
    private func csv(_ lines: [String]) -> Data {
        Data(("\u{feff}sightingId,date,longitude,latitude,scientificName,count,countType,note,sessionId,sessionTitle\r\n" + lines.joined(separator: "\r\n") + "\r\n").utf8)
    }
    private func line(_ id: String, date: String = "2020-01-01T10:00:00Z", group: String = "", title: String = "") -> String {
        "\(id),\(date),4.4,51.2,Testus birdus,99,UNKNOWN,,\(group),\(title)"
    }
    private func batch() throws -> BirdaImportBatch {
        try BirdaImport.decode(csv([
            line(two, date: "2020-01-01T12:00:00.000Z", group: session, title: "Testsessie"),
            line(one, group: session, title: "Testsessie"), line(three)
        ]), catalog: [bird])
    }
    func testCountOneMinMaxSessionsSingletonAndSourcePreservation() throws {
        let result = try batch()
        XCTAssertEqual(result.observations.count, 3)
        XCTAssertEqual(result.speciesCount, 1)
        XCTAssertEqual(result.standaloneCount, 1)
        let group = try XCTUnwrap(result.sessions.first)
        XCTAssertEqual(group.id, UUID(uuidString: session))
        XCTAssertEqual(group.locationName, "Testsessie")
        XCTAssertEqual(group.endedAt!.timeIntervalSince(group.startedAt), 7200)
        XCTAssertTrue(result.observations.allSatisfy { $0.count == 1 && $0.latitude == 51.2 && $0.longitude == 4.4 })
        XCTAssertEqual(result.observations.first?.importMetadata?["count"], "99")
        XCTAssertEqual(result.observations.first?.importMetadata?["countType"], "UNKNOWN")
        XCTAssertEqual(result.observations.first?.source, "birda-csv")
        XCTAssertEqual(result.observations.last?.id, UUID(uuidString: three))
    }
    func testQuotedCommasNewlinesEscapedQuotesAndScientificAliases() throws {
        let data = csv(["\(one),2020-01-01T10:00:00Z,4.4,51.2,Oldus birdus,1,EXACT,\"Een, twee\n\"\"drie\"\"\",,\"Naam, test\""])
        let result = try BirdaImport.decode(data, catalog: [bird])
        XCTAssertEqual(result.observations.first?.notes, "Een, twee\n\"drie\"")
        XCTAssertEqual(result.observations.first?.speciesID, bird.id)
    }
    func testExplicitTimeOffsetKeepsSameInstantWithoutTimezoneSuffix() throws {
        let result = try BirdaImport.decode(csv([line(one), line(two, date: "2020-01-01T15:30:00+05:30")]), catalog: [bird])
        XCTAssertEqual(result.observations[0].observedAt, result.observations[1].observedAt)
        XCTAssertFalse(result.observations[0].historyDate().contains("UTC"))
        XCTAssertEqual(result.observations[0].historyTimeZone.secondsFromGMT(for: result.observations[0].observedAt), 0)
        var local = result.observations[0]
        local.timeZoneIdentifier = "Asia/Kolkata"
        XCTAssertFalse(local.historyDate().contains("UTC"))
        XCTAssertEqual(local.historyTimeZone.secondsFromGMT(for: local.observedAt), 19800)
    }
    func testInvalidDataNeverDropsRowsSilently() {
        let valid = line(one)
        let bad = [line(one), line(two).replacingOccurrences(of: "51.2", with: "NaN"),
            line(two).replacingOccurrences(of: "Testus birdus", with: "Unknown bird"),
            line(two).replacingOccurrences(of: "10:00:00Z", with: "10:00:00"),
            line(two) + ",extra", line(two).replacingOccurrences(of: "Testus birdus", with: "\"Testus birdus")]
        for invalid in bad {
            XCTAssertThrowsError(try BirdaImport.decode(csv([valid, invalid]), catalog: [bird]))
        }
    }
    func testAmbiguousAliasRejectedAndZeroDurationAllowed() throws {
        let other = Species(id: "other", taxonomyVersion: "test", dutchName: "Andere", englishName: "Other", scientificName: "Testus birdus")
        XCTAssertThrowsError(try BirdaImport.decode(csv([line(one)]), catalog: [bird, other]))
        let result = try BirdaImport.decode(csv([line(one, group: session), line(two, group: session)]), catalog: [bird])
        XCTAssertEqual(result.sessions.first?.startedAt, result.sessions.first?.endedAt)
        XCTAssertEqual(result.observations.count, 2) // Repeat sightings of the same species are not deduplicated.
    }
    func testImportMergeRepeatAndPersistenceKeepExistingHistoryAndEdits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("observations.json")
        let store = ObservationStore(persistence: JSONObservationPersistence(url: url))
        var existing = Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion,
            observedAt: Date(), locationName: "Bestaand", count: 3, notes: "Bewaren", status: .confirmed)
        try store.save(existing)
        let goal = BirdGoal(name: "Bestaande doelstelling", speciesIDs: [bird.id])
        try store.addGoal(goal)
        let imported = try batch()
        let result = try store.importBirda(imported, expectedRevision: store.revision)
        XCTAssertEqual(result.addedObservations, 3)
        XCTAssertEqual(store.observations.count, 4)
        var edited = try XCTUnwrap(store.observations.first { $0.id == UUID(uuidString: one) })
        edited.notes = "Bewerkt"; edited.count = 4
        try store.save(edited, editing: true)
        let revision = store.revision
        let repeated = try store.importBirda(imported, expectedRevision: revision)
        XCTAssertEqual(repeated.addedObservations, 0)
        XCTAssertEqual(repeated.skipped, 3)
        XCTAssertEqual(store.revision, revision)
        XCTAssertEqual(store.observations.first { $0.id == edited.id }, edited)
        let reopened = ObservationStore(persistence: JSONObservationPersistence(url: url))
        XCTAssertNil(reopened.loadError)
        XCTAssertEqual(reopened.observations, store.observations)
        XCTAssertEqual(reopened.sessions, store.sessions)
        XCTAssertEqual(reopened.goals, [goal])
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("RecoveryCopies").path).isEmpty)
        existing.notes = "Gewijzigd"
        try store.save(existing, editing: true)
        XCTAssertThrowsError(try store.importBirda(imported, expectedRevision: revision))
    }
    func testUnrelatedUUIDCollisionAndChangedSessionBoundsRejectMerge() throws {
        let imported = try batch()
        var collision = imported.observations[0]; collision.source = "personal-manual"
        XCTAssertThrowsError(try BirdaImport.plan(imported, observations: [collision], sessions: imported.sessions))
        var changed = imported.sessions[0]
        changed.startedAt = changed.endedAt!
        XCTAssertThrowsError(try BirdaImport.plan(imported, observations: [], sessions: [changed]))
    }
    func testFailedSaveDoesNotPublishAnythingAndGoalsArePreserved() throws {
        let goal = BirdGoal(name: "Test", speciesIDs: [bird.id], createdAt: Date())
        let archive = BirdingArchive(observations: [], sessions: [], goals: [goal])
        let persistence = FailingRestorePersistence(original: archive)
        let store = ObservationStore(persistence: persistence)
        let revision = store.revision
        XCTAssertThrowsError(try store.importBirda(batch(), expectedRevision: revision))
        XCTAssertTrue(store.observations.isEmpty)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.goals, [goal])
        XCTAssertEqual(store.revision, revision)
    }
    func testOldRecordsDecodeWithoutImportMetadata() throws {
        let imported = try batch()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(imported.observations[0])) as? [String: Any])
        json.removeValue(forKey: "importMetadata"); json.removeValue(forKey: "timeZoneIdentifier")
        let decoded = try JSONDecoder().decode(Observation.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.importMetadata)
        XCTAssertNil(decoded.timeZoneIdentifier)
    }
}

@MainActor
final class CountryRepairTests: XCTestCase {
    private func log(latitude: Double = 51.2194, longitude: Double = 4.4025, country: String? = nil) -> Observation {
        var log = Observation(speciesID: "test-bird", taxonomyVersion: "test-v1", observedAt: Date(timeIntervalSince1970: 1000),
            locationName: "Bestaande locatie", count: 7, notes: "Bewaar deze notitie", status: .confirmed)
        log.latitude = latitude; log.longitude = longitude; log.countryCode = country
        log.source = "birda-csv"; log.importMetadata = ["sightingId": log.id.uuidString]
        return log
    }
    func testOfflineCountriesIslandsEnclavesAndInvalidInput() throws {
        let index = try CountryBoundaryIndex.bundled.get()
        for (lat, lon, code) in [(51.2194, 4.4025, "BE"), (28.6139, 77.209, "IN"),
                                 (59.91, 10.75, "NO"), (48.85, 2.35, "FR"), (-20.93, 55.30, "RE"),
                                 (-29.316, 27.486, "LS"), (41.903, 12.453, "VA"), (-16.84, -179.97, "FJ")] {
            XCTAssertEqual(index.country(latitude: lat, longitude: lon), code)
        }
        XCTAssertNil(index.country(latitude: 0, longitude: 0))
        XCTAssertNil(index.country(latitude: .nan, longitude: 0))
        XCTAssertNil(index.country(latitude: 91, longitude: 4))
        XCTAssertThrowsError(try CountryBoundaryIndex(data: Data("corrupt".utf8)))
    }
    func testBackfillPersistsOnlyCountryAndPreservesSessionsGoalsAndAllOtherFields() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("records.json")
        let persistence = JSONObservationPersistence(url: url)
        var first = log(), second = log(latitude: 28.6139, longitude: 77.209)
        let session = BirdSession(locationName: "Eigen sessietitel", latitude: first.latitude!, longitude: first.longitude!,
            countryCode: nil, startedAt: first.observedAt, endedAt: first.observedAt, isLive: false)
        first.sessionID = session.id; second.sessionID = session.id
        let goal = BirdGoal(name: "Bestaande doelstelling", speciesIDs: [first.speciesID])
        try persistence.save([first, second], sessions: [session], goals: [goal])
        let store = ObservationStore(persistence: persistence)
        let results = [CountryResolution(request: CountryRepairRequest(id: first.id, isSession: false, latitude: first.latitude!, longitude: first.longitude!), code: "BE"),
            CountryResolution(request: CountryRepairRequest(id: second.id, isSession: false, latitude: second.latitude!, longitude: second.longitude!), code: "IN"),
            CountryResolution(request: CountryRepairRequest(id: session.id, isSession: true, latitude: session.latitude, longitude: session.longitude), code: "BE")]
        XCTAssertEqual(try store.applyCountryResolutions(results), 3)
        var expectedFirst = first, expectedSecond = second, expectedSession = session
        expectedFirst.countryCode = "BE"; expectedSecond.countryCode = "IN"; expectedSession.countryCode = "BE"
        XCTAssertEqual(store.observations, [expectedFirst, expectedSecond])
        XCTAssertEqual(store.sessions, [expectedSession]); XCTAssertEqual(store.goals, [goal])
        XCTAssertEqual(CountryProjection.countries(in: store.observations).count, 2)
        let revision = store.revision
        XCTAssertEqual(try store.applyCountryResolutions(results), 0)
        XCTAssertEqual(store.revision, revision)
        let reopened = ObservationStore(persistence: persistence)
        XCTAssertEqual(reopened.observations, store.observations)
        XCTAssertEqual(reopened.sessions, store.sessions)
    }
    func testKnownCountriesChangedCoordinatesAndDeletedRecordsAreNotOverwritten() throws {
        let known = log(country: "NL"), moved = log(latitude: 52, longitude: 5)
        let archive = BirdingArchive(observations: [known, moved], sessions: [])
        let store = ObservationStore(persistence: ReadOnlyCountryFixture(archive: archive))
        let revision = store.revision
        let requests = [known.id, moved.id, UUID()].map {
            CountryResolution(request: CountryRepairRequest(id: $0, isSession: false, latitude: 51.2194, longitude: 4.4025), code: "BE")
        }
        XCTAssertEqual(try store.applyCountryResolutions(requests), 0)
        XCTAssertEqual(store.observations, archive.observations)
        XCTAssertEqual(store.revision, revision)
    }
    func testFailedCountrySaveLeavesStoreAndRevisionUntouched() throws {
        let record = log()
        let archive = BirdingArchive(observations: [record], sessions: [])
        let store = ObservationStore(persistence: FailingRestorePersistence(original: archive))
        let revision = store.revision
        let result = CountryResolution(request: CountryRepairRequest(id: record.id, isSession: false,
            latitude: record.latitude!, longitude: record.longitude!), code: "BE")
        XCTAssertThrowsError(try store.applyCountryResolutions([result]))
        XCTAssertEqual(store.observations, [record]); XCTAssertEqual(store.revision, revision)
    }
    func testOfflineRepairMakesNoGeocodingRequestForLandCoordinates() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = JSONObservationPersistence(url: folder.appendingPathComponent("records.json"))
        try persistence.save([log(), log(latitude: 28.6139, longitude: 77.209)], sessions: [])
        let store = ObservationStore(persistence: persistence)
        let naming = CountryNamingFixture()
        let controller = CountryRepairController(naming: naming, delay: .zero)
        await controller.repair(store: store)
        XCTAssertEqual(naming.calls, 0)
        XCTAssertEqual(store.observations.map(\.countryCode), ["BE", "IN"])
        XCTAssertNil(controller.errorMessage)
    }
    func testFallbackGroupsExactCoordinatesAndDoesNotInventCountryAtZeroZero() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = JSONObservationPersistence(url: folder.appendingPathComponent("records.json"))
        try persistence.save([log(latitude: 35, longitude: -30), log(latitude: 35, longitude: -30), log(latitude: 0, longitude: 0)], sessions: [])
        let store = ObservationStore(persistence: persistence)
        let naming = CountryNamingFixture()
        let controller = CountryRepairController(naming: naming, delay: .zero)
        await controller.repair(store: store)
        XCTAssertEqual(naming.calls, 1)
        XCTAssertEqual(store.observations.map(\.countryCode), ["PT", "PT", nil])
        await controller.repair(store: store)
        XCTAssertEqual(naming.calls, 1)
    }
    func testGeocodingWithoutResultsContinuesAndCachesOnlyAttempts() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = JSONObservationPersistence(url: folder.appendingPathComponent("records.json"))
        try persistence.save([log(latitude: 35, longitude: -30), log(latitude: 36, longitude: -30)], sessions: [])
        let store = ObservationStore(persistence: persistence)
        let naming = CountryNamingFixture(); naming.noResult = true
        let controller = CountryRepairController(naming: naming, delay: .zero)
        await controller.repair(store: store)
        XCTAssertEqual(naming.calls, 2)
        XCTAssertTrue(store.observations.allSatisfy { $0.countryCode == nil })
        XCTAssertNil(controller.errorMessage)
        await controller.repair(store: store)
        XCTAssertEqual(naming.calls, 2)
    }
    func testNetworkFailureKeepsOfflineSuccessesAndPausesFurtherRequests() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = JSONObservationPersistence(url: folder.appendingPathComponent("records.json"))
        try persistence.save([log(), log(latitude: 35, longitude: -30), log(latitude: 36, longitude: -30)], sessions: [])
        let store = ObservationStore(persistence: persistence)
        let naming = CountryNamingFixture(); naming.fails = true
        let controller = CountryRepairController(naming: naming, delay: .zero)
        await controller.repair(store: store)
        XCTAssertEqual(store.observations.map(\.countryCode), ["BE", nil, nil])
        XCTAssertNotNil(controller.errorMessage)
        await controller.repair(store: store)
        XCTAssertEqual(naming.calls, 1)
    }
}

private struct ReadOnlyCountryFixture: ObservationPersistence {
    let archive: BirdingArchive
    func load() throws -> [Observation] { archive.observations }
    func loadSessions() throws -> [BirdSession] { archive.sessions }
    func save(_ observations: [Observation]) throws { throw CocoaError(.fileWriteUnknown) }
}
@MainActor private final class CountryNamingFixture: PlaceNamingService {
    var calls = 0
    var fails = false
    var noResult = false
    func suggestion(latitude: Double, longitude: Double) async throws -> PlaceSuggestion {
        calls += 1
        if fails { throw CocoaError(.fileReadUnknown) }
        if noResult { throw CLError(.geocodeFoundNoResult) }
        return PlaceSuggestion(name: "Synthetische test", countryCode: "PT")
    }
}

@MainActor
final class HistoryManagementTests: XCTestCase {
    private let bird = MockSpeciesRepository.kingfisher
    private func archive() -> BirdingArchive {
        let time = Date(timeIntervalSince1970: 1000)
        let session = BirdSession(locationName: "Sessie", latitude: 51, longitude: 4, countryCode: "BE", startedAt: time,
            endedAt: time.addingTimeInterval(100), isLive: false)
        var one = Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion, observedAt: time,
            locationName: "Eerste plek", count: 3, notes: "Bewaren", status: .confirmed)
        one.latitude = 51; one.longitude = 4; one.countryCode = "BE"; one.sessionID = session.id
        one.source = "birda-csv"; one.importMetadata = ["sightingId": one.id.uuidString]
        var two = one; two.id = UUID(); two.observedAt = time.addingTimeInterval(50)
        two.latitude = 52; two.longitude = 5; two.locationName = "Andere plek"; two.countryCode = "NL"
        var loose = one; loose.id = UUID(); loose.sessionID = nil
        return BirdingArchive(observations: [one,two,loose], sessions: [session], goals: [BirdGoal(name: "Doel", speciesIDs: [bird.id])])
    }
    private func makeStore(_ archive: BirdingArchive) throws -> ObservationStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let persistence = JSONObservationPersistence(url: directory.appendingPathComponent("history.json"))
        try persistence.save(archive.observations, sessions: archive.sessions, goals: archive.goals ?? [])
        return ObservationStore(persistence: persistence)
    }
    func testConvertSessionRetainsExactObservationsExceptSessionLink() throws {
        let original = archive(), store = try makeStore(original)
        try store.deleteSession(id: original.sessions[0].id, keepObservations: true)
        let expected = original.observations.map { log -> Observation in var copy = log; copy.sessionID = nil; return copy }
        XCTAssertEqual(store.observations, expected)
        XCTAssertEqual(store.goals, original.goals ?? [])
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.observations.count, 3)
    }
    func testDeleteSessionRemovesOnlyItsLogsAndDeleteGoalDoesNotAffectHistory() throws {
        let original = archive(), store = try makeStore(original)
        try store.deleteSession(id: original.sessions[0].id)
        XCTAssertEqual(store.observations, [original.observations[2]])
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.goals, original.goals ?? [])
        try store.deleteGoal(id: store.goals[0].id)
        XCTAssertTrue(store.goals.isEmpty)
        XCTAssertEqual(store.observations, [original.observations[2]])
    }
    func testDeleteObservationKeepsOtherRecordsAndExistingSession() throws {
        let original = archive(), store = try makeStore(original)
        try store.deleteObservation(id: original.observations[0].id)
        XCTAssertEqual(store.observations, Array(original.observations.dropFirst()))
        XCTAssertEqual(store.sessions, original.sessions)
        XCTAssertEqual(store.goals, original.goals ?? [])
    }
    func testFailedDeletionOrConversionNeverPublishesPartialData() {
        for operation in 0...3 {
            let original = archive()
            let store = ObservationStore(persistence: FailingRestorePersistence(original: original))
            let revision = store.revision
            XCTAssertThrowsError(try {
                switch operation {
                case 0: try store.deleteObservation(id: original.observations[0].id)
                case 1: try store.deleteSession(id: original.sessions[0].id)
                case 2: try store.deleteSession(id: original.sessions[0].id, keepObservations: true)
                default: try store.deleteGoal(id: original.goals![0].id)
                }
            }())
            XCTAssertEqual(store.observations, original.observations)
            XCTAssertEqual(store.sessions, original.sessions)
            XCTAssertEqual(store.goals, original.goals ?? [])
            XCTAssertEqual(store.revision, revision)
        }
    }
    func testAudioOneTapCreatesAndAddsAtomicallyThenReusesSessionAndRejectsDuplicate() throws {
        let store = try makeStore(BirdingArchive(observations: [], sessions: []))
        let point = SessionLogLocation(latitude: 51, longitude: 4, name: "Plek", countryCode: "BE")
        let date = Date(timeIntervalSince1970: 1000)
        try store.logAudio(bird, at: date, location: point)
        let session = try XCTUnwrap(store.activeSession)
        XCTAssertEqual(store.sessions.count, 1); XCTAssertEqual(store.observations.count, 1)
        XCTAssertEqual(store.observations[0].sessionID, session.id)
        XCTAssertEqual(store.observations[0].observedAt, date)
        XCTAssertEqual(store.observations[0].status, .confirmed)
        XCTAssertThrowsError(try store.logAudio(bird, at: date.addingTimeInterval(1), location: point))
        let second = Species(id: "other-test", taxonomyVersion: "test", dutchName: "Andere", englishName: "Other", scientificName: "Other")
        try store.logAudio(second, at: date.addingTimeInterval(10), location: point)
        XCTAssertEqual(store.sessions.count, 1); XCTAssertEqual(store.observations.count, 2)
        XCTAssertThrowsError(try store.deleteSession(id: session.id, keepObservations: true))
        try store.deleteSession(id: session.id)
        XCTAssertNil(store.activeSession); XCTAssertTrue(store.observations.isEmpty)
    }
    func testFailedFirstAudioLogDoesNotLeaveEmptyLiveSession() {
        let original = BirdingArchive(observations: [], sessions: [])
        let store = ObservationStore(persistence: FailingRestorePersistence(original: original))
        let revision = store.revision
        XCTAssertThrowsError(try store.logAudio(bird, at: Date(), location: SessionLogLocation(latitude: 51, longitude: 4, name: "Plek", countryCode: "BE")))
        XCTAssertTrue(store.sessions.isEmpty); XCTAssertTrue(store.observations.isEmpty)
        XCTAssertEqual(store.revision, revision)
    }
    func testReimportAfterConversionDoesNotRecreateEmptyBirdaSession() throws {
        let sessionID = UUID(), one = UUID(), two = UUID()
        let text = "sightingId,date,longitude,latitude,scientificName,sessionId,sessionTitle\n\(one),2020-01-01T10:00:00Z,4,51,Alcedo atthis,\(sessionID),Test\n\(two),2020-01-01T11:00:00Z,4,51,Alcedo atthis,\(sessionID),Test\n"
        let batch = try BirdaImport.decode(Data(text.utf8), catalog: [bird])
        let store = try makeStore(BirdingArchive(observations: [], sessions: []))
        try store.importBirda(batch, expectedRevision: store.revision)
        try store.deleteSession(id: sessionID, keepObservations: true)
        let result = try store.importBirda(batch, expectedRevision: store.revision)
        XCTAssertEqual(result.addedObservations, 0); XCTAssertEqual(result.addedSessions, 0)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.observations.allSatisfy { $0.sessionID == nil })
    }
}

final class FirstObservationMapTests: XCTestCase {
    private func record(_ species: String, at time: Double, latitude: Double = 51, longitude: Double = 4) -> Observation {
        var log = Observation(speciesID: species, taxonomyVersion: "test", observedAt: Date(timeIntervalSince1970: time),
            locationName: "Plek", count: 1, notes: "", status: .confirmed)
        log.latitude = latitude; log.longitude = longitude
        return log
    }
    func testOnlyFirstPerSpeciesAndStableTieOrderWithoutMergingSamePlaceSpecies() {
        let old = record("bird-a", at: 10), recent = record("bird-a", at: 30), other = record("bird-b", at: 20)
        let result = FirstObservationMapProjection.records([recent, other, old])
        XCTAssertEqual(Set(result.map(\.id)), Set([old.id, other.id]))
        XCTAssertEqual(FirstObservationMapProjection.records([old,recent,other]), result)
        var tie = old
        tie.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(FirstObservationMapProjection.records([old,tie]).first?.id, tie.id)
    }
    func testUnknownFirstCoordinatesDoNotInventOrSubstituteAPlace() {
        let first = record("bird-a", at: 1, latitude: 0, longitude: 0)
        let later = record("bird-a", at: 2)
        var missing = record("bird-b", at: 1); missing.latitude = nil; missing.longitude = nil
        XCTAssertTrue(FirstObservationMapProjection.records([first,later,missing]).isEmpty)
        XCTAssertTrue(FirstObservationMapProjection.records([record("bad", at: 0, latitude: .nan)]).isEmpty)
    }
}

@MainActor
final class MapsHomeAndMilestoneTests: XCTestCase {
    private func log(_ species: String, latitude: Double? = nil, longitude: Double? = nil) -> Observation {
        var log = Observation(speciesID: species, taxonomyVersion: "test", observedAt: Date(), locationName: "Testplek", count: 1, notes: "", status: .confirmed)
        log.latitude = latitude; log.longitude = longitude
        return log
    }
    func testHomeFilterUsesDistanceNotNameOrCountry() {
        let home = HomeLogbookLocation(latitude: 50, longitude: 4, name: "Testadres")
        XCTAssertTrue(home.contains(log("near", latitude: 50.001, longitude: 4)))
        XCTAssertFalse(home.contains(log("far", latitude: 50.002, longitude: 4)))
        XCTAssertFalse(home.contains(log("missing")))
        XCTAssertFalse(home.contains(log("zero", latitude: 0, longitude: 0)))
        XCTAssertFalse(home.contains(log("invalid", latitude: .nan, longitude: 4)))
        XCTAssertEqual(HomeLogbookLocation.load(home.encoded), home)
        XCTAssertNil(HomeLogbookLocation.load("{\"latitude\":200,\"longitude\":4,\"name\":\"invalid\"}"))
    }
    func testRankingKeepsOneCoherentSourceReport() throws {
        let bird = MockSpeciesRepository.kingfisher
        let now = Date()
        let latest = NearbyReport(checklistID: "S100", species: bird, observedAt: now, latitude: 50, longitude: 4,
            localObservedAt: "2026-11-24 10:00", locationName: "Eerste plek", observerName: "Eerste waarnemer")
        let older = NearbyReport(checklistID: "observation:2", species: bird, observedAt: now.addingTimeInterval(-60), latitude: 50.001, longitude: 4,
            observationURL: URL(string: "https://observation.org/observation/2/"), locationName: "Andere plek", observerName: "Andere waarnemer")
        let rows = DiscoverRanking.ranked([latest, older], query: .init(latitude: 50, longitude: 4, now: now, radiusKilometers: 5), ordering: .providerRecency)
        let report = try XCTUnwrap(rows.first?.report)
        XCTAssertEqual(report.checklistID, "S100")
        XCTAssertEqual(report.latitude, 50)
        XCTAssertEqual(report.locationName, "Eerste plek")
        XCTAssertEqual(report.observerName, "Eerste waarnemer")
        XCTAssertEqual(rows.first?.reportCount, 2)
    }
    func testOptionalPublicMetadataDoesNotBreakOldFeeds() throws {
        let legacy = Data(#"{"speciesCode":"x","sciName":"Test bird","obsDt":"2026-11-24","lat":50,"lng":4,"subId":"S1","obsValid":true}"#.utf8)
        let decoded = try JSONDecoder().decode(EBirdObservation.self, from: legacy)
        XCTAssertNil(decoded.locName)
        XCTAssertNil(decoded.userDisplayName)
        let publicRecord = Data(#"{"id":12,"date":"2026-11-24","time":null,"species_detail":{"scientific_name":"Test bird","group":1,"type":"S"},"point":{"coordinates":[4,50]},"is_certain":true,"location_detail":{"name":"Testgebied"},"user":123}"#.utf8)
        let record = try JSONDecoder().decode(ObservationOrgRecord.self, from: publicRecord)
        XCTAssertEqual(record.location_detail?.name, "Testgebied")
        XCTAssertEqual(record.user, 123)
        XCTAssertNil(record.time)
    }
    func testMilestoneTotalsUseConfirmedUniqueWildSpecies() {
        let first = log("first")
        var uncertain = log("uncertain"); uncertain.status = .uncertain
        var captive = log("captive"); captive.isCaptive = true
        let earned = MilestoneProjection.earned(observations: [first, log("first"), uncertain, captive], goals: [], catalog: [])
        XCTAssertEqual(earned.map(\.id), ["lifelist-1"])
        let ten = (0..<10).map { log("species-\($0)") }
        XCTAssertEqual(MilestoneProjection.earned(observations: ten, goals: [], catalog: []).map(\.id), ["lifelist-1", "lifelist-10"])
    }
    func testFirstOwlAndCompletedGoal() {
        let owl = Species(id: "owl", taxonomyVersion: "test", dutchName: "Testuil", englishName: "Test owl", scientificName: "Test owl", family: BirdFamily(id: "Strigidae", dutchName: "Uilen"))
        let goal = BirdGoal(name: "Testdoel", speciesIDs: [owl.id])
        let earned = MilestoneProjection.earned(observations: [log(owl.id)], goals: [goal], catalog: [owl])
        XCTAssertTrue(earned.contains { $0.id == "first-owl" })
        XCTAssertTrue(earned.contains { $0.id == "goal-\(goal.id)" })
        XCTAssertFalse(earned.contains { $0.id.hasPrefix("family-") })
    }
    func testMilestonesNeverReplayAfterRestartImportOrRestore() throws {
        let suite = "milestone-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = MilestoneController(defaults: defaults)
        let initialEpoch = UUID()
        controller.update(observations: [], goals: [], catalog: [], historyReplacementID: initialEpoch)
        let first = log("first")
        controller.update(observations: [first], goals: [], catalog: [], historyReplacementID: initialEpoch)
        XCTAssertEqual(controller.current?.id, "lifelist-1")
        controller.advance()
        controller.update(observations: [], goals: [], catalog: [], historyReplacementID: initialEpoch)
        controller.update(observations: [first], goals: [], catalog: [], historyReplacementID: initialEpoch)
        XCTAssertNil(controller.current)
        let restored = (0..<50).map { log("restored-\($0)") }
        let restoredEpoch = UUID()
        controller.update(observations: restored, goals: [], catalog: [], historyReplacementID: restoredEpoch)
        XCTAssertNil(controller.current)
        let restarted = MilestoneController(defaults: defaults)
        restarted.update(observations: restored, goals: [], catalog: [], historyReplacementID: restoredEpoch)
        XCTAssertNil(restarted.current)
        var imported = log("imported"); imported.source = "birda-csv"
        restarted.update(observations: restored + [imported], goals: [], catalog: [], historyReplacementID: UUID())
        XCTAssertNil(restarted.current)
    }
}

@MainActor
final class FineControlRenderingRegressionTests: XCTestCase {
    private let canvas = CGRect(x: 0, y: 0, width: 24, height: 24)
    private func ink(_ symbol: String, at point: CGPoint) -> Bool {
        FineControlMark(symbol: symbol).path(in: canvas)
            .strokedPath(FieldGuideTheme.navigationStroke).contains(point)
    }
    func testPlayRetainsClosedTriangleAndHouseRetainsBothSides() {
        let play = FineControlMark(symbol: "play").path(in: canvas)
        XCTAssertTrue(play.contains(CGPoint(x: 10, y: 12)), "A play button must enclose a triangle, not collapse to one diagonal")
        XCTAssertTrue(ink("house", at: CGPoint(x: 6.5, y: 5.5)), "Left roof slope must remain connected")
        XCTAssertTrue(ink("house", at: CGPoint(x: 4, y: 16)), "Left wall must be drawn")
        XCTAssertTrue(ink("house", at: CGPoint(x: 20, y: 16)))
        XCTAssertTrue(ink("house", at: CGPoint(x: 12, y: 22)))
        XCTAssertFalse(ink("house", at: CGPoint(x: 12, y: 18)), "Simple house has no door")
    }
    func testClockAndBackupRetainBothHandsAndBackupArrow() {
        for symbol in ["clock", "clock.arrow.circlepath"] {
            XCTAssertTrue(ink(symbol, at: CGPoint(x: 12, y: 8)), "Vertical clock hand missing")
            XCTAssertTrue(ink(symbol, at: CGPoint(x: 16, y: 12)), "Horizontal clock hand missing")
        }
        XCTAssertTrue(ink("clock.arrow.circlepath", at: CGPoint(x: 17, y: 4.6)), "Backup arrowhead must have both strokes")
    }
    func testSortRetainsCompleteArrowheads() {
        for point in [CGPoint(x: 3.5, y: 4.5), CGPoint(x: 8.5, y: 4.5),
                      CGPoint(x: 15.5, y: 19.5), CGPoint(x: 20.5, y: 19.5)] {
            XCTAssertTrue(ink("arrow.up.arrow.down", at: point))
        }
    }
}
