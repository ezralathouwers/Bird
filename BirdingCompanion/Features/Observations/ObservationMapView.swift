import SwiftUI
import MapKit

@MainActor
final class ObservationNavigation: ObservableObject {
    @Published var selection: Observation?
    private(set) var species: Species?

    func open(_ observation: Observation, species: Species) {
        self.species = species
        selection = observation
    }
}

struct ObservationMapView: View {
    let observation: Observation
    let species: Species
    @EnvironmentObject private var store: ObservationStore
    @StateObject private var connectivity = MapConnectivity()
    @State private var editing = false
    @State private var camera: MapCameraPosition = .automatic

    private var current: Observation {
        store.observations.first { $0.id == observation.id } ?? observation
    }
    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude = current.latitude, let longitude = current.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Map(position: $camera) {
            if let coordinate {
                Annotation(species.dutchName, coordinate: coordinate) {
                    SpeciesObservationMarker(species: species)
                }.annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .accessibilityLabel("Locatie van je waarneming van \(species.dutchName)")
        .overlay(alignment: .top) {
            VStack(spacing: 12) {
                observationInfo
                if coordinate == nil || connectivity.isOffline {
                    Text(coordinate == nil
                         ? "Bij deze waarneming is geen kaartlocatie opgeslagen. Voeg een plek toe via Bewerken."
                         : "Offline: de basiskaart is mogelijk onvolledig. Je opgeslagen waarnemingsplek blijft beschikbaar.")
                        .font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FieldGuideTheme.ivory, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .fullScreenCover(isPresented: $editing) { ObservationForm(species: species, observation: current) }
        .onAppear { centerMap() }
        .onChange(of: current.latitude) { _, _ in centerMap() }
        .onChange(of: current.longitude) { _, _ in centerMap() }
    }

    private var observationInfo: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(species.dutchName)
                    .font(.custom("Fraunces-9ptBlack", size: 22, relativeTo: .title2).weight(.regular))
                Text(current.observedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(FieldGuideTheme.sans(15, relativeTo: .subheadline))
                Label(current.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      ? "Geen locatie opgegeven" : current.locationName, systemImage: "mappin")
                    .font(FieldGuideTheme.sans(15, relativeTo: .subheadline))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { editing = true } label: {
                Image(systemName: "pencil").frame(width: 44, height: 44)
            }.accessibilityLabel("Bewerk datum of locatie")
        }
        .foregroundStyle(FieldGuideTheme.charcoal)
        .padding(16)
        .background(FieldGuideTheme.ivory, in: RoundedRectangle(cornerRadius: 16))
    }

    private func centerMap() {
        guard let coordinate else { return }
        camera = .region(MKCoordinateRegion(center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
    }
}

private struct SpeciesObservationMarker: View {
    let species: Species
    var body: some View {
        Group {
            // Hook for the approved primary illustration; never reuse the habitat artwork.
            if UIImage(named: SpeciesMediaRole.classic.assetName(for: species)) != nil {
                PrimaryBirdImage(species: species)
            } else {
                Image(systemName: "bird").font(.system(size: 28, weight: .light))
                    .foregroundStyle(FieldGuideTheme.charcoal)
            }
        }
        .frame(width: 60, height: 60)
        .background(FieldGuideTheme.ivory)
        .clipShape(Circle())
        .overlay { Circle().stroke(FieldGuideTheme.taupe, lineWidth: 1) }
        .accessibilityLabel("\(species.dutchName), waarnemingsplek")
        .accessibilityHint(UIImage(named: SpeciesMediaRole.classic.assetName(for: species)) == nil ? "Primaire vogelillustratie nog niet beschikbaar" : "")
    }
}
