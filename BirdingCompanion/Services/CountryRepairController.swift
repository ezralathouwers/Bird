import Foundation
import Combine
@preconcurrency import CoreLocation

struct CountryRepairRequest: Hashable, Sendable {
    let id: UUID
    let isSession: Bool
    let latitude: Double
    let longitude: Double
}
struct CountryResolution: Sendable {
    let request: CountryRepairRequest
    let code: String
}
private struct CountryLookupCoordinate: Hashable, Sendable { let latitude: Double; let longitude: Double }

@MainActor
final class CountryRepairController: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    private let naming: any PlaceNamingService
    private let delay: Duration
    private var workerTask: Task<Void, Never>?
    private var pending = false
    private var isActive = true
    private var onlinePaused = false
    private var attempted: [CountryLookupCoordinate: Date] = [:]

    init(naming: any PlaceNamingService = ApplePlaceNamingService(), delay: Duration = .milliseconds(1500)) {
        self.naming = naming; self.delay = delay
    }
    func schedule(store: ObservationStore) {
        guard isActive, store.loadError == nil else { return }
        guard workerTask == nil else { pending = true; return }
        workerTask = Task {
            await repair(store: store)
            workerTask = nil
            if pending { pending = false; schedule(store: store) }
        }
    }
    func pause() { isActive = false; pending = false; workerTask?.cancel() }
    func resume(store: ObservationStore) { isActive = true; onlinePaused = false; schedule(store: store) }
    func retry(store: ObservationStore) { attempted.removeAll(); onlinePaused = false; errorMessage = nil; schedule(store: store) }

    func repair(store: ObservationStore) async {
        guard store.loadError == nil, !Task.isCancelled else { return }
        let logs = store.observations.compactMap { log -> CountryRepairRequest? in
            guard ObservationCountry.normalized(log.countryCode) == nil,
                  let latitude = log.latitude, let longitude = log.longitude else { return nil }
            return CountryRepairRequest(id: log.id, isSession: false, latitude: latitude, longitude: longitude)
        }
        let sessions = store.sessions.compactMap { session -> CountryRepairRequest? in
            guard ObservationCountry.normalized(session.countryCode) == nil else { return nil }
            return CountryRepairRequest(id: session.id, isSession: true, latitude: session.latitude, longitude: session.longitude)
        }
        let requests = logs + sessions
        guard !requests.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        let offline = Task.detached(priority: .utility) {
            let index = try CountryBoundaryIndex.bundled.get()
            let grouped = Dictionary(grouping: requests) { CountryLookupCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
            var results: [CountryResolution] = []
            var unresolved: [CountryLookupCoordinate: [CountryRepairRequest]] = [:]
            for (point, items) in grouped {
                try Task.checkCancellation()
                if let code = index.country(latitude: point.latitude, longitude: point.longitude) {
                    results += items.map { CountryResolution(request: $0, code: code) }
                } else { unresolved[point] = items }
            }
            return (results, unresolved)
        }
        do {
            let (results, unresolved) = try await withTaskCancellationHandler {
                try await offline.value
            } onCancel: { offline.cancel() }
            try Task.checkCancellation()
            try store.applyCountryResolutions(results)
            guard !onlinePaused else { return }
            attempted = attempted.filter { Date().timeIntervalSince($0.value) < 900 }
            let points = unresolved.keys.sorted { $0.latitude == $1.latitude ? $0.longitude < $1.longitude : $0.latitude < $1.latitude }
            for point in points {
                try Task.checkCancellation()
                // Do not invent a country for the export's unset-location sentinel.
                guard point.latitude != 0 || point.longitude != 0, attempted[point] == nil else { continue }
                try await Task.sleep(for: delay)
                do {
                    let suggestion = try await naming.suggestion(latitude: point.latitude, longitude: point.longitude)
                    try Task.checkCancellation()
                    if let code = ObservationCountry.normalized(suggestion.countryCode) {
                        let resolved = (unresolved[point] ?? []).map { CountryResolution(request: $0, code: code) }
                        try store.applyCountryResolutions(resolved)
                    }
                    attempted[point] = Date()
                } catch is CancellationError { throw CancellationError() }
                catch let error as CLError where error.code == .geocodeFoundNoResult || error.code == .geocodeFoundPartialResult {
                    attempted[point] = Date()
                } catch {
                    try Task.checkCancellation()
                    // Keep successes and pause on network/write errors instead of retrying
                    // hundreds of requests. Resume/retry uses a fresh persisted snapshot.
                    onlinePaused = true
                    errorMessage = "Landen aanvullen is onderbroken. \(error.localizedDescription)"
                    return
                }
            }
            errorMessage = nil
        } catch is CancellationError {
            // Resume on returning to the foreground, using the current stored data.
        } catch { errorMessage = error.localizedDescription }
    }
}
