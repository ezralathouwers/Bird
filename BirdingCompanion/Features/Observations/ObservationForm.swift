import SwiftUI
import MapKit

struct ObservationForm: View {
    let species: Species
    private let original: Observation?
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var observedAt: Date
    @State private var locationName: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var notes: String
    @State private var errorMessage: String?

    init(species: Species, observation: Observation? = nil) {
        self.species = species
        original = observation
        _observedAt = State(initialValue: observation?.observedAt ?? Date())
        _locationName = State(initialValue: observation?.locationName ?? "")
        _notes = State(initialValue: observation?.notes ?? "")
        _latitude = State(initialValue: observation?.latitude)
        _longitude = State(initialValue: observation?.longitude)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(species.dutchName) {
                    DatePicker("Datum en tijd", selection: $observedAt)
                    TextField("Locatie (optioneel)", text: $locationName)
                    TextField("Notities", text: $notes, axis: .vertical).lineLimit(3...8)
                }
                Section("Locatie op de kaart (optioneel)") {
                    ObservationLocationPicker(latitude: $latitude, longitude: $longitude)
                        .frame(height: 220)
                    Text("Tik op de kaart om de exacte plek vast te leggen. Een locatienaam alleen plaatst geen marker.")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                    if latitude != nil {
                        Button("Verwijder kaartlocatie") { latitude = nil; longitude = nil }
                    }
                }
                Section {
                    Text("Lokaal opgeslagen op dit apparaat. Door op Opslaan te tikken leg je een persoonlijke waarneming vast.")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).accessibilityLabel("Opslaan mislukt: \(errorMessage)") }
            }
            .navigationTitle(original == nil ? "Waarneming toevoegen" : "Waarneming bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") { save() }.disabled(store.loadError != nil)
                }
            }
        }
    }

    private func save() {
        var record = original ?? Observation(speciesID: species.id, taxonomyVersion: species.taxonomyVersion,
            observedAt: observedAt, locationName: locationName, count: 1, notes: notes,
            status: .confirmed)
        record.observedAt = observedAt
        record.locationName = locationName
        record.notes = notes
        record.latitude = latitude
        record.longitude = longitude
        do { try store.save(record, editing: original != nil); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct ObservationLocationPicker: View {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let latitude, let longitude {
                    Marker("Waarnemingsplek", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                }
            }
        }
        .accessibilityLabel("Kies de waarnemingsplek op de kaart")
        .onAppear {
            camera = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude ?? 51, longitude: longitude ?? 5),
                span: MKCoordinateSpan(latitudeDelta: latitude == nil ? 10 : 0.03,
                                       longitudeDelta: longitude == nil ? 14 : 0.03)
            ))
        }
    }
}
