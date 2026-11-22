import Foundation
import Combine

@MainActor final class SessionLiveLogger: ObservableObject {
    @Published private(set) var isLogging = false
    @Published private(set) var message: String?
    private let location: any CurrentLocationService
    private let naming: any PlaceNamingService
    private var pending: Task<Void, Never>?
    init(location: any CurrentLocationService = SharedCurrentLocation.shared, naming: any PlaceNamingService = ApplePlaceNamingService()) {
        self.location = location; self.naming = naming
    }
    func log(_ species: Species, store: ObservationStore, completion: @escaping () -> Void = {}) {
        guard !isLogging else { return }
        guard let session = store.activeSession else { message = SessionError.noActiveSession.localizedDescription; return }
        guard !store.observations(in: session).contains(where: { $0.speciesID == species.id }) else {
            message = SessionError.duplicateSpecies.localizedDescription; return
        }
        let tappedAt = Date()
        isLogging = true; message = nil
        pending = Task { [weak self, location, naming] in
            do {
                let fix = try await location.current(policy: .liveLog)
                let suggestion = try? await naming.suggestion(latitude: fix.latitude, longitude: fix.longitude)
                guard let self, !Task.isCancelled else { return }
                let name = suggestion?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let point = SessionLogLocation(latitude: fix.latitude, longitude: fix.longitude,
                    name: name.isEmpty ? String(format: "%.5f, %.5f", fix.latitude, fix.longitude) : name,
                    countryCode: suggestion?.countryCode)
                try store.logLive(species, sessionID: session.id, at: tappedAt, location: point)
                self.isLogging = false; self.pending = nil; self.message = nil
                completion()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.isLogging = false; self.pending = nil
                self.message = "De vogel is niet opgeslagen. \(error.localizedDescription)"
            }
        }
    }
}
