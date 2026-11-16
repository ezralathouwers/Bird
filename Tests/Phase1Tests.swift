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
