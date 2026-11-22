import Foundation
import Combine
@preconcurrency import CoreLocation

// One foreground location request per tap. No continuous/background tracking.
@MainActor
final class SessionLiveLogger: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var isLogging = false
    @Published private(set) var message: String?
    private let manager = CLLocationManager()
    private var pending: Pending?
    private var timeout: Task<Void, Never>?
    private var naming: Task<Void, Never>?

    private struct Pending {
        let id = UUID()
        let species: Species
        let store: ObservationStore
        let sessionID: UUID
        let tappedAt: Date
        let completion: () -> Void
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func log(_ species: Species, store: ObservationStore, completion: @escaping () -> Void = {}) {
        guard !isLogging else { return }
        guard let session = store.activeSession else { message = SessionError.noActiveSession.localizedDescription; return }
        guard !store.observations(in: session).contains(where: { $0.speciesID == species.id }) else {
            message = SessionError.duplicateSpecies.localizedDescription; return
        }
        let request = Pending(species: species, store: store, sessionID: session.id, tappedAt: Date(), completion: completion)
        pending = request; isLogging = true; message = nil
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(40))
            guard !Task.isCancelled, self?.pending?.id == request.id else { return }
            self?.fail("Geen actuele locatie ontvangen. De vogel is niet opgeslagen. Probeer opnieuw.")
        }
        requestLocation()
    }

    private func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: fail("Locatietoegang is nodig om live te loggen. Sta locatie toe in Instellingen en probeer opnieuw.")
        @unknown default: fail("Je actuele locatie is niet beschikbaar. De vogel is niet opgeslagen.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if pending != nil { requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if pending != nil { fail("Je actuele locatie kon niet worden opgehaald. De vogel is niet opgeslagen.") }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let request = pending, naming == nil else { return }
        guard let fix = locations.last, fix.horizontalAccuracy >= 0,
              abs(fix.timestamp.timeIntervalSince(request.tappedAt)) <= 20 else {
            fail("Geen voldoende recente GPS-positie ontvangen. De vogel is niet opgeslagen."); return
        }
        let latitude = fix.coordinate.latitude, longitude = fix.coordinate.longitude
        naming = Task { [weak self] in
            let suggestion = try? await ApplePlaceNamingService().suggestion(latitude: latitude, longitude: longitude)
            guard !Task.isCancelled, let self, self.pending?.id == request.id else { return }
            let name = suggestion?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let point = SessionLogLocation(latitude: latitude, longitude: longitude,
                name: name.isEmpty ? String(format: "%.5f, %.5f", latitude, longitude) : name,
                countryCode: suggestion?.countryCode)
            do {
                try request.store.logLive(request.species, sessionID: request.sessionID, at: request.tappedAt, location: point)
                self.clear()
                self.message = nil
                request.completion()
            } catch { self.fail(error.localizedDescription) }
        }
    }

    private func fail(_ text: String) { clear(); message = text }
    private func clear() {
        timeout?.cancel(); timeout = nil
        naming?.cancel(); naming = nil
        manager.stopUpdatingLocation()
        pending = nil; isLogging = false
    }
}
