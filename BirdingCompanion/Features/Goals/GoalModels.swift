import Foundation

struct BirdGoal: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var speciesIDs: [String]
    var createdAt = Date()
    var favoriteSpeciesID: String? = nil

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !speciesIDs.isEmpty, speciesIDs.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(speciesIDs).count == speciesIDs.count else { throw GoalError.invalidGoal }
        guard favoriteSpeciesID.map({ speciesIDs.contains($0) }) ?? true else { throw GoalError.invalidFavorite }
    }

    func completedIDs(in observations: [Observation]) -> Set<String> {
        Set(speciesIDs).intersection(Set(observations.map(\.speciesID)))
    }
}

enum GoalError: LocalizedError {
    case invalidGoal, invalidFavorite, duplicateID, missingGoal, unsupportedPersistence
    var errorDescription: String? {
        switch self {
        case .invalidGoal: "Geef je doelstelling een naam en selecteer minstens één vogelsoort."
        case .invalidFavorite: "De favoriete vogel moet deel uitmaken van je doelstelling."
        case .missingGoal: "Deze doelstelling is niet meer beschikbaar."
        case .duplicateID: "Deze doelstelling bestaat al."
        case .unsupportedPersistence: "Deze opslag ondersteunt nog geen doelstellingen."
        }
    }
}

struct GoalSpeciesSelection {
    var ids: Set<String> = []
    var favoriteID: String? = nil
    mutating func toggle(_ id: String) {
        if ids.remove(id) != nil {
            if favoriteID == id { favoriteID = nil }
        } else { ids.insert(id) }
    }
    mutating func chooseFavorite(_ id: String) {
        ids.insert(id)
        favoriteID = id
    }
}
