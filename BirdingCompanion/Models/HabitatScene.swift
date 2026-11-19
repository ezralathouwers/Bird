import Foundation

struct HabitatScene: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let group: String
    let assetName: String
    let illustrationBrief: String
}

struct SpeciesHabitatAssignment: Codable, Sendable {
    let speciesID: String
    let scientificName: String
    let primarySceneID: String
    let secondarySceneIDs: [String]
    let reviewStatus: String
    let reviewedAt: String
    let sourceURLs: [URL]
}

struct HabitatSceneLibrary: Sendable {
    let scenes: [HabitatScene]
    let assignments: [SpeciesHabitatAssignment]
    private let scenesByID: [String: HabitatScene]
    private let assignmentsByID: [String: SpeciesHabitatAssignment]

    init(scenes: [HabitatScene], assignments: [SpeciesHabitatAssignment]) throws {
        let ids = Set(scenes.map(\.id))
        guard ids.count == scenes.count, scenes.allSatisfy({ !$0.id.isEmpty && !$0.assetName.isEmpty }),
              Set(assignments.map(\.speciesID)).count == assignments.count else { throw HabitatSceneError.invalidData }
        for assignment in assignments {
            guard !assignment.speciesID.isEmpty, !assignment.scientificName.isEmpty,
                  ["source-checked", "draft"].contains(assignment.reviewStatus), ids.contains(assignment.primarySceneID),
                  assignment.secondarySceneIDs.allSatisfy({ ids.contains($0) && $0 != assignment.primarySceneID }),
                  Set(assignment.secondarySceneIDs).count == assignment.secondarySceneIDs.count,
                  !assignment.sourceURLs.isEmpty,
                  assignment.sourceURLs.allSatisfy({ ["https", "http"].contains($0.scheme ?? "") }) else { throw HabitatSceneError.invalidData }
        }
        self.scenes = scenes; self.assignments = assignments
        scenesByID = Dictionary(uniqueKeysWithValues: scenes.map { ($0.id, $0) })
        assignmentsByID = Dictionary(uniqueKeysWithValues: assignments.map { ($0.speciesID, $0) })
    }

    func primaryScene(for speciesID: String) -> HabitatScene? {
        guard let assignment = assignmentsByID[speciesID], assignment.reviewStatus == "source-checked" else { return nil }
        return scenesByID[assignment.primarySceneID]
    }
    func assignment(for speciesID: String) -> SpeciesHabitatAssignment? { assignmentsByID[speciesID] }
}

enum HabitatSceneError: Error { case invalidData }

enum HabitatSceneCatalog {
    private struct Snapshot: Sendable {
        let library: HabitatSceneLibrary?
        let error: String?
    }
    private static let snapshot: Snapshot = {
        do {
            guard let scenes = Bundle.main.url(forResource: "HabitatScenes", withExtension: "json"),
                  let assignments = Bundle.main.url(forResource: "SpeciesHabitatAssignments", withExtension: "json") else {
                throw HabitatSceneError.invalidData
            }
            let decoded = try JSONDecoder().decode([SpeciesHabitatAssignment].self, from: Data(contentsOf: assignments))
            guard decoded.allSatisfy({ SpeciesGuideCatalog.species(id: $0.speciesID)?.scientificName == $0.scientificName }) else {
                throw HabitatSceneError.invalidData
            }
            return Snapshot(library: try HabitatSceneLibrary(
                scenes: JSONDecoder().decode([HabitatScene].self, from: Data(contentsOf: scenes)), assignments: decoded), error: nil)
        } catch { return Snapshot(library: nil, error: "De leefomgevingsindeling kon niet worden geladen.") }
    }()
    static var assignments: [SpeciesHabitatAssignment] { snapshot.library?.assignments ?? [] }
    static var scenes: [HabitatScene] { snapshot.library?.scenes ?? [] }
    static var loadError: String? { snapshot.error }
    static func primaryScene(for species: Species) -> HabitatScene? { snapshot.library?.primaryScene(for: species.id) }
}
