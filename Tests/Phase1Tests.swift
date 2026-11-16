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
