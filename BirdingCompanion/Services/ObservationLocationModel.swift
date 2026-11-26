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
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else { throw CLError(.geocodeFoundNoResult) }
        return try await SharedPlaceNaming.shared.suggestion(latitude: latitude, longitude: longitude)
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
final class ObservationLocationModel: NSObject, ObservableObject {
    @Published private(set) var latitude: Double?
    @Published private(set) var longitude: Double?
    @Published private(set) var locationName: String
    @Published private(set) var countryCode: String?
    @Published private(set) var isLocating = false
    @Published private(set) var isNaming = false
    @Published private(set) var message: String?
    private let currentLocation: any CurrentLocationService
    private let locationPolicy: AppLocationPolicy
    private var locationTask: Task<Void, Never>?
    private let namingService: any PlaceNamingService
    private var namingTask: Task<Void, Never>?
    private var selectionID = UUID()
    private var nameWasEdited = false

    init(observation: Observation? = nil, namingService: any PlaceNamingService = ApplePlaceNamingService(), currentLocation: any CurrentLocationService = SharedCurrentLocation.shared, locationPolicy: AppLocationPolicy = .observation) {
        self.namingService = namingService
        self.currentLocation = currentLocation
        self.locationPolicy = locationPolicy
        latitude = observation?.latitude
        longitude = observation?.longitude
        locationName = observation?.locationName ?? ""
        countryCode = observation?.countryCode
        super.init()
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

    @discardableResult func useCurrentLocation() -> Task<Void, Never> {
        locationTask?.cancel(); namingTask?.cancel(); isNaming = false
        isLocating = true; message = nil
        let id = UUID(); selectionID = id
        let task = Task { [weak self, currentLocation, locationPolicy] in
            do {
                let fix = try await currentLocation.current(policy: locationPolicy)
                guard let self, self.selectionID == id, !Task.isCancelled else { return }
                await self.select(latitude: fix.latitude, longitude: fix.longitude)?.value
            } catch {
                guard let self, self.selectionID == id, !Task.isCancelled else { return }
                self.isLocating = false
                self.message = "Je huidige locatie is niet beschikbaar. Kies een plek op de kaart of probeer opnieuw."
            }
        }
        locationTask = task
        return task
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
                try await Task.sleep(for: .milliseconds(100))
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
        locationTask?.cancel(); locationTask = nil
        namingTask?.cancel()
        isNaming = false
    }
}

struct AppLocationFix: Sendable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    func isUsable(maxAge: TimeInterval, maxAccuracy: Double, now: Date) -> Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && accuracy >= 0 && accuracy <= maxAccuracy && abs(timestamp.timeIntervalSince(now)) <= maxAge
    }
}
struct AppLocationPolicy: Sendable {
    let maxAge: TimeInterval
    let maxAccuracy: Double
    let desiredAccuracy: Double
    let timeout: TimeInterval
    static let browsing = Self(maxAge: 60, maxAccuracy: 500, desiredAccuracy: 100, timeout: 10)
    static let observation = Self(maxAge: 30, maxAccuracy: 150, desiredAccuracy: 100, timeout: 10)
    static let liveLog = Self(maxAge: 15, maxAccuracy: 100, desiredAccuracy: 10, timeout: 15)
}
@MainActor protocol CurrentLocationService {
    func current(policy: AppLocationPolicy) async throws -> AppLocationFix
}

@MainActor final class SharedCurrentLocation: NSObject, CurrentLocationService, @preconcurrency CLLocationManagerDelegate {
    static let shared = SharedCurrentLocation()
    private struct Request {
        let policy: AppLocationPolicy
        let continuation: CheckedContinuation<AppLocationFix, Error>
        let timeout: Task<Void, Never>
    }
    private let manager = CLLocationManager()
    private var latest: AppLocationFix?
    private var requests: [UUID: Request] = [:]
    override init() { super.init(); manager.delegate = self }
    func prewarmIfAuthorized() async {
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        _ = try? await current(policy: .browsing)
    }
    func current(policy: AppLocationPolicy) async throws -> AppLocationFix {
        try Task.checkCancellation()
        switch manager.authorizationStatus {
        case .denied, .restricted: throw CLError(.denied)
        default: break
        }
        let authorized = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
        let cached = (authorized ? [latest, manager.location.map(Self.fix)] : []).compactMap { $0 }
            .filter { $0.isUsable(maxAge: policy.maxAge, maxAccuracy: policy.maxAccuracy, now: Date()) }
            .max { $0.timestamp < $1.timestamp }
        if let cached { latest = cached; return cached }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                let timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(policy.timeout))
                    guard !Task.isCancelled else { return }
                    self?.finish(id, result: .failure(CLError(.locationUnknown)))
                }
                requests[id] = Request(policy: policy, continuation: continuation, timeout: timeout)
                requestHardware()
            }
        } onCancel: { Task { @MainActor [weak self] in self?.finish(id, result: .failure(CancellationError())) } }
    }
    private static func fix(_ location: CLLocation) -> AppLocationFix {
        AppLocationFix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy, timestamp: location.timestamp)
    }
    private func requestHardware() {
        guard !requests.isEmpty else { manager.stopUpdatingLocation(); return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.desiredAccuracy = requests.values.map(\.policy.desiredAccuracy).min() ?? 100
            manager.startUpdatingLocation()
        case .denied, .restricted:
            for id in Array(requests.keys) { finish(id, result: .failure(CLError(.denied))) }
        @unknown default:
            for id in Array(requests.keys) { finish(id, result: .failure(CLError(.locationUnknown))) }
        }
    }
    private func finish(_ id: UUID, result: Result<AppLocationFix, Error>) {
        guard let request = requests.removeValue(forKey: id) else { return }
        request.timeout.cancel(); request.continuation.resume(with: result)
        if requests.isEmpty { manager.stopUpdatingLocation() }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { requestHardware() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            let fix = Self.fix(location)
            if fix.isUsable(maxAge: 120, maxAccuracy: 1000, now: Date()) { latest = fix }
            for (id, request) in Array(requests) where fix.isUsable(maxAge: request.policy.maxAge, maxAccuracy: request.policy.maxAccuracy, now: Date()) {
                finish(id, result: .success(fix))
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown { return } // Core Location may recover before the bounded timeout.
        for id in Array(requests.keys) { finish(id, result: .failure(error)) }
    }
}

@MainActor private final class SharedPlaceNaming {
    static let shared = SharedPlaceNaming()
    private struct Entry { let latitude: Double; let longitude: Double; let value: PlaceSuggestion; let date: Date }
    private var entries: [Entry] = []
    private var pending: [String: Task<PlaceSuggestion, Error>] = [:]
    func suggestion(latitude: Double, longitude: Double) async throws -> PlaceSuggestion {
        entries.removeAll { Date().timeIntervalSince($0.date) > 1800 }
        let point = CLLocation(latitude: latitude, longitude: longitude)
        if let entry = entries.min(by: {
            point.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) < point.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }), point.distance(from: CLLocation(latitude: entry.latitude, longitude: entry.longitude)) <= 75 { return entry.value }
        let key = "\(Int((latitude * 10000).rounded())),\(Int((longitude * 10000).rounded()))"
        if let task = pending[key] { return try await task.value }
        let task = Task<PlaceSuggestion, Error> {
            try await withThrowingTaskGroup(of: PlaceSuggestion.self) { group in
                group.addTask { try await Self.reverse(latitude: latitude, longitude: longitude) }
                group.addTask { try await Task.sleep(for: .seconds(3)); throw CLError(.network) }
                defer { group.cancelAll() }
                guard let value = try await group.next() else { throw CLError(.geocodeFoundNoResult) }
                return value
            }
        }
        pending[key] = task
        defer { pending.removeValue(forKey: key) }
        let value = try await task.value
        entries.append(Entry(latitude: latitude, longitude: longitude, value: value, date: Date()))
        if entries.count > 128 { entries.removeFirst(entries.count - 128) }
        return value
    }
    private static func reverse(latitude: Double, longitude: Double) async throws -> PlaceSuggestion {
        let geocoder = CLGeocoder()
        return try await withTaskCancellationHandler {
            let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), preferredLocale: Locale(identifier: "nl_BE"))
            guard let place = placemarks.first else { throw CLError(.geocodeFoundNoResult) }
            let name = PlaceNameSuggestion.preferred(area: place.areasOfInterest?.first, locality: place.locality, name: place.name, region: place.administrativeArea)
            return PlaceSuggestion(name: name ?? "", countryCode: ObservationCountry.normalized(place.isoCountryCode))
        } onCancel: { Task { @MainActor in geocoder.cancelGeocode() } }
    }
}

// Coordinate text remains recoverable in metadata; it is not a useful place title.
enum LocationNameDisplay {
    static func needsName(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || ["onbekend", "locatie onbekend", "onbekende locatie", "geen locatie opgegeven"].contains(value.lowercased()) { return true }
        guard value.rangeOfCharacter(from: .decimalDigits) != nil,
              let numbers = try? NSRegularExpression(pattern: #"[+\-−]?\d+(?:[.,]\d+)?"#),
              numbers.numberOfMatches(in: value, range: NSRange(value.startIndex..., in: value)) >= 2 else { return false }
        return value.range(of: #"^[\s\d+\-−.,;°'"′″NSEWnsew()\[\]/]+$"#, options: .regularExpression) != nil
    }
    static func title(_ value: String, countryCode: String? = nil) -> String {
        if !needsName(value) { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let code = ObservationCountry.normalized(countryCode) { return ObservationCountry.name(for: code) }
        return "Locatie onbekend"
    }
}

struct PlaceNameRepairRequest: Sendable {
    let id: UUID
    let isSession: Bool
    let latitude: Double
    let longitude: Double
    let originalName: String
}
struct PlaceNameResolution: Sendable {
    let request: PlaceNameRepairRequest
    let name: String
    let countryCode: String?
}

@MainActor
final class PlaceNameRepairController: ObservableObject {
    @Published private(set) var message: String?
    private let naming: any PlaceNamingService
    private let delay: Duration
    private var task: Task<Void, Never>?
    private var active = true
    private var pending = false
    private var pausedAfterError = false
    private var historyID: UUID?
    private var attempted: [String: Date] = [:]
    init(naming: any PlaceNamingService = ApplePlaceNamingService(), delay: Duration = .milliseconds(1500)) {
        self.naming = naming; self.delay = delay
    }
    func schedule(store: ObservationStore) {
        guard active, !pausedAfterError, store.loadError == nil else { return }
        guard task == nil else { pending = true; return }
        task = Task {
            await repair(store: store)
            task = nil
            if pending { pending = false; schedule(store: store) }
        }
    }
    func pause() { active = false; pending = false; task?.cancel() }
    func resume(store: ObservationStore) { active = true; pausedAfterError = false; schedule(store: store) }
    func repair(store: ObservationStore) async {
        guard store.loadError == nil, !Task.isCancelled else { return }
        do { try store.inheritSessionLocationNames() }
        catch {
            pausedAfterError = true; message = "Locatienamen konden niet veilig worden opgeslagen. Probeer opnieuw na heropenen."
            return
        }
        let history = store.historyReplacementID
        if historyID != history { attempted.removeAll(); historyID = history }
        attempted = attempted.filter { Date().timeIntervalSince($0.value) < 900 }
        let sessions = store.sessions.filter { LocationNameDisplay.needsName($0.locationName) }.map {
            PlaceNameRepairRequest(id: $0.id, isSession: true, latitude: $0.latitude, longitude: $0.longitude, originalName: $0.locationName)
        }
        let logs = store.observations.compactMap { log -> PlaceNameRepairRequest? in
            guard LocationNameDisplay.needsName(log.locationName), let lat = log.latitude, let lon = log.longitude else { return nil }
            return PlaceNameRepairRequest(id: log.id, isSession: false, latitude: lat, longitude: lon, originalName: log.locationName)
        }
        // Sessions first: one resolved session name can cover all its linked logs.
        let ordered = sessions + logs
        var seen = Set<String>()
        for request in ordered {
            guard !Task.isCancelled, store.historyReplacementID == history else { return }
            guard request.latitude.isFinite, request.longitude.isFinite,
                  (-90...90).contains(request.latitude), (-180...180).contains(request.longitude),
                  request.latitude != 0 || request.longitude != 0 else { continue }
            let key = "\(Int((request.latitude * 10000).rounded())),\(Int((request.longitude * 10000).rounded()))"
            guard !seen.contains(key), attempted[key] == nil, store.needsPlaceName(request) else { continue }
            seen.insert(key)
            do {
                try await Task.sleep(for: delay)
                let suggestion = try await naming.suggestion(latitude: request.latitude, longitude: request.longitude)
                try Task.checkCancellation()
                guard store.historyReplacementID == history else { return }
                attempted[key] = Date()
                guard !LocationNameDisplay.needsName(suggestion.name) else { continue }
                let matching = ordered.filter {
                    Int(($0.latitude * 10000).rounded()) == Int((request.latitude * 10000).rounded()) &&
                    Int(($0.longitude * 10000).rounded()) == Int((request.longitude * 10000).rounded())
                }.map { PlaceNameResolution(request: $0, name: suggestion.name, countryCode: suggestion.countryCode) }
                try store.applyPlaceNames(matching)
                message = nil
            } catch is CancellationError { return }
            catch let error as CLError where error.code == .geocodeFoundNoResult || error.code == .geocodeFoundPartialResult {
                attempted[key] = Date()
            } catch {
                guard !Task.isCancelled else { return }
                pausedAfterError = true
                message = "Locatienamen aanvullen is onderbroken. Bij de volgende appactivatie wordt dit opnieuw geprobeerd."
                return
            }
        }
    }
}
