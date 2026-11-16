import Foundation
import Combine
@preconcurrency import CoreLocation

struct PlaceSuggestion: Sendable {
    let name: String
    let countryCode: String?
}

@MainActor
protocol PlaceNamingService {
    func suggestion(latitude: Double, longitude: Double) async throws -> PlaceSuggestion
}

@MainActor
struct ApplePlaceNamingService: PlaceNamingService {
    func suggestion(latitude: Double, longitude: Double) async throws -> PlaceSuggestion {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: latitude, longitude: longitude), preferredLocale: Locale(identifier: "nl_BE"))
        guard let place = placemarks.first else { throw CLError(.geocodeFoundNoResult) }
        let name = PlaceNameSuggestion.preferred(
            area: place.areasOfInterest?.first, locality: place.locality,
            name: place.name, region: place.administrativeArea)
        return PlaceSuggestion(name: name ?? "", countryCode: ObservationCountry.normalized(place.isoCountryCode))
    }
}

enum PlaceNameSuggestion {
    static func preferred(area: String?, locality: String?, name: String?, region: String?) -> String? {
        [area, locality, name, region].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }
}

@MainActor
final class ObservationLocationModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var latitude: Double?
    @Published private(set) var longitude: Double?
    @Published private(set) var locationName: String
    @Published private(set) var countryCode: String?
    @Published private(set) var isLocating = false
    @Published private(set) var isNaming = false
    @Published private(set) var message: String?
    private let manager = CLLocationManager()
    private let namingService: any PlaceNamingService
    private var namingTask: Task<Void, Never>?
    private var selectionID = UUID()
    private var nameWasEdited = false

    init(observation: Observation? = nil, namingService: any PlaceNamingService = ApplePlaceNamingService()) {
        self.namingService = namingService
        latitude = observation?.latitude
        longitude = observation?.longitude
        locationName = observation?.locationName ?? ""
        countryCode = observation?.countryCode
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var canSave: Bool {
        guard let latitude, let longitude else { return false }
        return latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
            && !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isNaming
    }

    func editName(_ name: String) {
        locationName = name
        nameWasEdited = true
    }

    func useCurrentLocation() {
        isLocating = true
        message = nil
        requestAuthorizedLocation()
    }

    private func requestAuthorizedLocation() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            message = "Geen toegang tot je locatie. Kies de waarnemingsplek op de kaart en vul de locatienaam in."
        @unknown default:
            isLocating = false
            message = "Je huidige locatie is niet beschikbaar. Kies een plek op de kaart."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isLocating { requestAuthorizedLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isLocating else { return } // Never replace a subsequent manual map choice.
        guard let location = locations.last, location.horizontalAccuracy >= 0,
              abs(location.timestamp.timeIntervalSinceNow) < 120 else {
            isLocating = false
            message = "Geen recente locatie ontvangen. Kies een plek op de kaart of probeer opnieuw."
            return
        }
        select(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isLocating else { return }
        isLocating = false
        message = "Je huidige locatie kon niet worden opgehaald. Kies een plek op de kaart of probeer opnieuw."
    }

    @discardableResult
    func select(latitude: Double, longitude: Double) -> Task<Void, Never>? {
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        isLocating = false
        self.latitude = latitude
        self.longitude = longitude
        countryCode = nil
        locationName = ""
        nameWasEdited = false
        message = nil
        namingTask?.cancel()
        let requestID = UUID()
        selectionID = requestID
        isNaming = true
        namingTask = Task { [weak self, namingService] in
            do {
                // Debounce repeated map taps; old results never override the latest selection.
                try await Task.sleep(for: .milliseconds(350))
                let suggestion = try await namingService.suggestion(latitude: latitude, longitude: longitude)
                guard !Task.isCancelled, let self, self.selectionID == requestID else { return }
                if !self.nameWasEdited { self.locationName = suggestion.name }
                self.countryCode = ObservationCountry.normalized(suggestion.countryCode)
                self.isNaming = false
                if self.locationName.isEmpty || self.countryCode == nil {
                    self.message = "De plaats of het land kon niet volledig worden bepaald. Je kunt de locatienaam zelf invullen."
                }
            } catch {
                guard !Task.isCancelled, let self, self.selectionID == requestID else { return }
                self.isNaming = false
                self.message = "Geen plaatsnaam of land gevonden. Controleer je verbinding en vul de locatienaam zelf in."
            }
        }
        return namingTask
    }

    func stop() {
        isLocating = false
        manager.stopUpdatingLocation()
        namingTask?.cancel()
        isNaming = false
    }
}
