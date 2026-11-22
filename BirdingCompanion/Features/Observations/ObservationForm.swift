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
        if original == nil, store.activeSession != nil {
            LiveSessionAddBirdView(species: species)
        } else {
            standardForm
        }
    }

    private var standardForm: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: original == nil ? "Waarneming toevoegen" : "Waarneming bewerken") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    selectedBird
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { dateAndTimeFields }
                        VStack(alignment: .leading, spacing: 12) { dateAndTimeFields }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Locatie").font(FieldGuideTheme.sans(20, relativeTo: .title3))
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)
                        ObservationLocationPicker(location: location).frame(height: 228)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        TextField("Naam van natuurgebied of plaats", text: Binding(
                            get: { location.locationName }, set: { location.editName($0) }))
                            .modifier(RoundedSearchField())
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
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            }
            .background(FieldGuideTheme.ivory)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: save) {
                    Text(original == nil ? "Waarneming opslaan" : "Wijzigingen opslaan")
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(FieldGuideTheme.ivory)
                        .background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius, style: .continuous))
                }
                .disabled(store.loadError != nil || !location.canSave)
                .opacity(store.loadError != nil || !location.canSave ? 0.4 : 1)
                .padding(20).background(FieldGuideTheme.ivory)
            }
            .task { if original == nil { location.useCurrentLocation() } }
            .onDisappear { location.stop() }
        }
        .foregroundStyle(FieldGuideTheme.charcoal)
        .background(FieldGuideTheme.ivory.ignoresSafeArea())
    }

    @ViewBuilder private var dateAndTimeFields: some View {
        DateTimeField(title: "Datum", selection: $observedAt, isDate: true)
        DateTimeField(title: "Tijd", selection: $observedAt, isDate: false)
    }

    private var selectedBird: some View {
        HStack(spacing: 14) {
            Group {
                if UIImage(named: SpeciesMediaRole.classic.assetName(for: species)) != nil {
                    PrimaryBirdImage(species: species)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "bird").font(.largeTitle)
                    }
                }
            }
            .frame(width: 84, height: 100)
            .accessibilityLabel("Primaire illustratie van \(species.dutchName)")
            VStack(alignment: .leading, spacing: 6) {
                Text(species.englishDisplayName).font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                SerifText(species.dutchName, size: 26, relativeTo: .title)
                    .minimumScaleFactor(0.8)
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

struct ObservationLocationPicker: View {
    @ObservedObject var location: ObservationLocationModel
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let latitude = location.latitude, let longitude = location.longitude {
                    Annotation("Waarnemingsplek", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                        Circle().fill(FieldGuideTheme.charcoal).frame(width: 18, height: 18)
                            .overlay { Circle().stroke(FieldGuideTheme.ivory, lineWidth: 2) }
                    }.annotationTitles(.hidden)
                }
            }
            .mapStyle(FieldGuideTheme.mapStyle)
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
