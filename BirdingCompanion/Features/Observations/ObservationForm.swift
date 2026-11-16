import SwiftUI
import MapKit

struct ObservationForm: View {
    let species: Species
    private let original: Observation?
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location: ObservationLocationModel
    @State private var observedAt: Date
    @State private var errorMessage: String?

    init(species: Species, observation: Observation? = nil) {
        self.species = species
        original = observation
        _observedAt = State(initialValue: observation?.observedAt ?? Date())
        _location = StateObject(wrappedValue: ObservationLocationModel(observation: observation))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    selectedBird
                    VStack(spacing: 12) {
                        DatePicker("Datum", selection: $observedAt, displayedComponents: .date)
                            .labelsHidden().accessibilityLabel("Datum")
                        DatePicker("Tijd", selection: $observedAt, displayedComponents: .hourAndMinute)
                            .labelsHidden().accessibilityLabel("Tijd")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Locatie").font(FieldGuideTheme.sans(20, relativeTo: .title3))
                            .accessibilityAddTraits(.isHeader)
                        ObservationLocationPicker(location: location).frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        TextField("Naam van natuurgebied of plaats", text: Binding(
                            get: { location.locationName }, set: { location.editName($0) }))
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Locatienaam")
                        if location.isLocating { ProgressView("Huidige locatie ophalen…") }
                        if location.isNaming { ProgressView("Plaatsnaam en land ophalen…") }
                        if let code = location.countryCode {
                            Text(ObservationCountry.name(for: code))
                                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                        }
                        if let message = location.message {
                            Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                        Button { location.useCurrentLocation() } label: {
                            Label("Gebruik huidige locatie", systemImage: "location")
                                .frame(minHeight: 44)
                        }.disabled(location.isLocating)
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }.padding(20)
            }
            .background(FieldGuideTheme.ivory)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: save) {
                    Text(original == nil ? "Waarneming opslaan" : "Wijzigingen opslaan")
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(FieldGuideTheme.ivory)
                        .background(FieldGuideTheme.charcoal, in: Capsule())
                }
                .disabled(store.loadError != nil || !location.canSave)
                .opacity(store.loadError != nil || !location.canSave ? 0.4 : 1)
                .padding(20).background(FieldGuideTheme.ivory)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(original == nil ? "Waarneming toevoegen" : "Waarneming bewerken")
                        .font(FieldGuideTheme.sans())
                        .foregroundStyle(FieldGuideTheme.charcoal)
                        .offset(y: 4)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 22, weight: .light))
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel("Terug zonder opslaan")
                        .offset(y: 4)
                }
            }
            .toolbarBackground(FieldGuideTheme.ivory, for: .navigationBar)
            .task { if original == nil { location.useCurrentLocation() } }
            .onDisappear { location.stop() }
        }
    }

    private var selectedBird: some View {
        HStack(spacing: 20) {
            Group {
                if UIImage(named: species.id + "-primary") != nil {
                    Image(species.id + "-primary").resizable().scaledToFit()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "bird").font(.largeTitle)
                        Text("Illustratie volgt").font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    }
                }
            }
            .frame(width: 110, height: 130)
            .background(FieldGuideTheme.beige.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel("Primaire illustratie van \(species.dutchName)")
            VStack(alignment: .leading, spacing: 6) {
                Text(species.englishName).font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                Text(species.dutchName).font(FieldGuideTheme.speciesTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func save() {
        guard location.canSave else { return }
        var record = original ?? Observation(speciesID: species.id, taxonomyVersion: species.taxonomyVersion,
            observedAt: observedAt, locationName: location.locationName, count: 1, notes: "", status: .confirmed)
        record.observedAt = observedAt
        record.locationName = location.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        record.latitude = location.latitude
        record.longitude = location.longitude
        record.countryCode = location.countryCode
        // Hidden legacy notes/count/status are preserved when editing.
        do { try store.save(record, editing: original != nil); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct ObservationLocationPicker: View {
    @ObservedObject var location: ObservationLocationModel
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let latitude = location.latitude, let longitude = location.longitude {
                    Marker("Waarnemingsplek", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    location.select(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
        }
        .accessibilityLabel("Kies de verplichte waarnemingsplek op de kaart")
        .onAppear { centerMap() }
        .onChange(of: location.latitude) { _, _ in centerMap() }
        .onChange(of: location.longitude) { _, _ in centerMap() }
    }

    private func centerMap() {
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude ?? 51, longitude: location.longitude ?? 5),
            span: MKCoordinateSpan(latitudeDelta: location.latitude == nil ? 10 : 0.03,
                                   longitudeDelta: location.latitude == nil ? 14 : 0.03)))
    }
}
