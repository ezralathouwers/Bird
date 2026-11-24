import SwiftUI
import CoreLocation
import MapKit

// Private address/coordinates stay in local preferences, never in the catalog.
struct HomeLogbookLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let name: String
    static let preferenceKey = "logbookHomeLocation.v1"
    static func load(_ value: String) -> Self? {
        guard let data = value.data(using: .utf8), let home = try? JSONDecoder().decode(Self.self, from: data),
              home.latitude.isFinite, home.longitude.isFinite,
              (-90...90).contains(home.latitude), (-180...180).contains(home.longitude) else { return nil }
        return home
    }
    var encoded: String { (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    func contains(_ log: Observation) -> Bool {
        guard let lat = log.latitude, let lon = log.longitude,
              lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon),
              lat != 0 || lon != 0 else { return false }
        return CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: lat, longitude: lon)) <= 150
    }
}

struct HomeLogbookSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(HomeLogbookLocation.preferenceKey) private var storedHome = ""
    @State private var address = ""
    @State private var searching = false
    @State private var choices: [HomeLogbookLocation] = []
    @State private var message: String?
    @State private var geocoder = CLGeocoder()
    let didSave: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Thuislocatie") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Toon vogels die je binnen 150 meter van thuis hebt gelogd. Je adres blijft op dit toestel; Apple zoekt de bijbehorende kaartlocatie op.")
                    BirdTextField("Straat, huisnummer, postcode en gemeente", text: $address)
                        .modifier(RoundedSearchField()).privacySensitive()
                    Button(searching ? "Adres zoeken…" : "Zoek thuisadres") { searching = true }
                        .buttonStyle(.bordered).disabled(searching || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let message { Text(message).foregroundStyle(.red) }
                    ForEach(Array(choices.enumerated()), id: \.offset) { _, home in
                        Button {
                            storedHome = home.encoded
                            didSave()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Map(initialPosition: .region(MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude),
                                    span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)))) {
                                    Annotation("Thuis", coordinate: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)) {
                                        Circle().fill(FieldGuideTheme.charcoal).frame(width: 14, height: 14)
                                    }.annotationTitles(.hidden)
                                    MapCircle(center: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude), radius: 150)
                                        .foregroundStyle(FieldGuideTheme.khaki.opacity(0.2))
                                }.mapStyle(FieldGuideTheme.mapStyle).mapControlVisibility(.hidden)
                                    .frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false)
                                Label(home.name, systemImage: "house")
                                Text("Gebruik deze plek · straal 150 m").font(FieldGuideTheme.sans(13))
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                                .background(FieldGuideTheme.beige, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).privacySensitive()
                    }
                    Text("Later wijzigen: houd de huisknop in je logboek ingedrukt.").font(FieldGuideTheme.sans(13))
                }.padding(20)
            }
        }.background(FieldGuideTheme.ivory).foregroundStyle(FieldGuideTheme.charcoal)
            .onAppear { address = HomeLogbookLocation.load(storedHome)?.name ?? "" }
            .task(id: searching) {
                guard searching else { return }
                defer { searching = false }
                choices = []; message = nil
                do {
                    let results = try await geocoder.geocodeAddressString(address)
                    try Task.checkCancellation()
                    choices = results.compactMap { place in
                        guard let coordinate = place.location?.coordinate else { return nil }
                        let name = [place.thoroughfare, place.subThoroughfare, place.postalCode, place.locality, place.country]
                            .compactMap { $0 }.joined(separator: " ")
                        return HomeLogbookLocation(latitude: coordinate.latitude, longitude: coordinate.longitude, name: name.isEmpty ? address : name)
                    }
                    if choices.isEmpty { message = "Geen adres gevonden. Controleer het adres of probeer opnieuw met internet." }
                } catch is CancellationError {} catch { message = "Adres kon niet worden opgehaald. Controleer je verbinding en probeer opnieuw." }
            }
            .onDisappear { geocoder.cancelGeocode() }
    }
}
