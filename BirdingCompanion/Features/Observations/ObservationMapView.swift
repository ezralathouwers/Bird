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
    @Environment(\.dismiss) private var dismiss
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
        ZStack {
            Map(position: $camera) {
                if let coordinate {
                    Annotation(species.dutchName, coordinate: coordinate) {
                        SpeciesObservationMarker(species: species)
                    }.annotationTitles(.hidden)
                }
        }
        .mapStyle(FieldGuideTheme.mapStyle)
        .ignoresSafeArea()
        .mapControlVisibility(.hidden)
        .accessibilityLabel("Locatie van je waarneming van \(species.dutchName)")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
            .padding(.horizontal, 20).padding(.bottom, 16).padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            MapCloseButton(label: "Sluit waarneming") { dismiss() }
                .padding(.trailing, 20).padding(.top, 12)
        }
        .fullScreenCover(isPresented: $editing) { ObservationForm(species: species, observation: current) }
        .onAppear { centerMap() }
        .onChange(of: store.observations.contains { $0.id == observation.id }) { _, exists in if !exists { dismiss() } }
        .onChange(of: current.latitude) { _, _ in centerMap() }
        .onChange(of: current.longitude) { _, _ in centerMap() }
    }

    private var observationInfo: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SerifText(species.dutchName, size: 22, relativeTo: .title2)
                Text(current.historyDate())
                    .font(FieldGuideTheme.sans(15, relativeTo: .subheadline))
                HStack(alignment: .top, spacing: 6) {
                    LocationOutlineMark().stroke(style: FieldGuideTheme.navigationStroke)
                        .frame(width: 24, height: 24).fixedSize().offset(x: -2, y: -2).accessibilityHidden(true)
                    Text(current.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "Geen locatie opgegeven" : current.locationName)
                }.font(FieldGuideTheme.sans(15, relativeTo: .subheadline)).padding(.top, 5)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { editing = true } label: {
                EditOutlineMark().stroke(style: FieldGuideTheme.navigationStroke)
                    .frame(width: 22, height: 22).frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).offset(x: 6, y: -6).accessibilityLabel("Bewerk datum of locatie")
        }
        .foregroundStyle(FieldGuideTheme.charcoal)
        .padding(16)
        .background(FieldGuideTheme.beige, in: RoundedRectangle(cornerRadius: 16))
    }

    private func centerMap() {
        guard let coordinate else { return }
        camera = .region(MKCoordinateRegion(center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
    }
}

struct SpeciesObservationMarker: View {
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
        .frame(width: 48, height: 48)
        .padding(12)
        .background(FieldGuideTheme.ivory)
        .clipShape(Circle())
        .overlay { Circle().stroke(FieldGuideTheme.taupe, lineWidth: 1) }
        .accessibilityLabel("\(species.dutchName), waarnemingsplek")
        .accessibilityHint(UIImage(named: SpeciesMediaRole.classic.assetName(for: species)) == nil ? "Primaire vogelillustratie nog niet beschikbaar" : "")
    }
}

// Public reports remain read-only and never become confirmed personal logs.
struct NearbyReportMapView: View {
    let report: NearbyReport
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic
    @StateObject private var connectivity = MapConnectivity()
    private var coordinate: CLLocationCoordinate2D { .init(latitude: report.latitude, longitude: report.longitude) }
    var body: some View {
        Map(position: $camera) {
            Annotation(report.species.dutchName, coordinate: coordinate) {
                SpeciesObservationMarker(species: report.species)
            }.annotationTitles(.hidden)
        }.mapStyle(FieldGuideTheme.mapStyle).mapControlVisibility(.hidden).ignoresSafeArea()
            .environment(\.colorScheme, .light)
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    if let url = report.observationURL ?? DiscoverRanking.checklistURL(report.checklistID) {
                        Link(destination: url) {
                            FineControlIcon(symbol: "arrow.up.right.square")
                                .frame(width: 44, height: 44).foregroundStyle(FieldGuideTheme.charcoal)
                                .background(FieldGuideTheme.ivory, in: Circle())
                        }.accessibilityLabel("Open oorspronkelijke waarneming")
                    }
                    MapCloseButton(label: "Sluit melding") { dismiss() }
                }.padding(.trailing, 20).padding(.top, 12)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    SerifText(report.species.dutchName, size: 22, relativeTo: .title2)
                    Text(report.localObservedAt?.isEmpty == false ? report.localObservedAt! : report.observedAt.formatted(date: .abbreviated, time: .shortened))
                    HStack(alignment: .top, spacing: 6) {
                        LocationOutlineMark().stroke(style: FieldGuideTheme.navigationStroke).frame(width: 24, height: 24).fixedSize().offset(y: -3)
                        Text(report.locationName?.isEmpty == false ? report.locationName! : String(format: "%.5f, %.5f", report.latitude, report.longitude))
                    }.padding(.top, 5)
                    Text(report.checklistID.hasPrefix("observation:") ? "Observation.org" : report.checklistID.hasPrefix("demo-") ? "Voorbeeldmelding" : "eBird")
                        .font(FieldGuideTheme.sans(12, relativeTo: .caption)).opacity(0.65)
                    if connectivity.isOffline { Text("Offline: de basiskaart kan onvolledig zijn.").font(FieldGuideTheme.sans(12)) }
                }.font(FieldGuideTheme.sans(15, relativeTo: .subheadline)).foregroundStyle(FieldGuideTheme.charcoal)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(FieldGuideTheme.beige, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
            }
            .onAppear { camera = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))) }
    }
}
