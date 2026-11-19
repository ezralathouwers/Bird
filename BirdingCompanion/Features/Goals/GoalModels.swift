import Foundation

struct BirdGoal: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var speciesIDs: [String]
    var createdAt = Date()

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !speciesIDs.isEmpty, speciesIDs.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(speciesIDs).count == speciesIDs.count else { throw GoalError.invalidGoal }
    }

    func completedIDs(in observations: [Observation]) -> Set<String> {
        Set(speciesIDs).intersection(Set(observations.map(\.speciesID)))
    }
}

enum GoalError: LocalizedError {
    case invalidGoal, duplicateID, unsupportedPersistence
    var errorDescription: String? {
        switch self {
        case .invalidGoal: "Geef je doelstelling een naam en selecteer minstens één vogelsoort."
        case .duplicateID: "Deze doelstelling bestaat al."
        case .unsupportedPersistence: "Deze opslag ondersteunt nog geen doelstellingen."
        }
    }
}
