import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var store: ObservationStore
    @ObservedObject var model: DiscoverViewModel
    @StateObject private var location = ObservationLocationModel()
    @State private var filter: DiscoverFilter = .all
    @State private var demo = false

    private var queryKey: String {
        guard let latitude = location.latitude, let longitude = location.longitude else { return "no-location" }
        return "\(latitude),\(longitude),\(demo)"
    }
    private var query: DiscoverQuery? {
        guard let latitude = location.latitude, let longitude = location.longitude else { return nil }
        return DiscoverQuery(latitude: latitude, longitude: longitude, now: Date(), radiusKilometers: 25)
    }
    private var locationTitle: String {
        if demo && location.latitude == nil { return "Voorbeeldlocatie" }
        if !location.locationName.isEmpty { return location.locationName }
        return location.latitude == nil ? "jouw omgeving" : "deze omgeving"
    }
    private var rows: [DiscoverSpecies] {
        DiscoverRanking.filtered(model.rows, filter: filter, observations: store.observations,
                                 statusAvailable: store.loadError == nil)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("Vandaag in \(locationTitle)")
                    .font(FieldGuideTheme.sans(34, relativeTo: .largeTitle))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Gemeld in de afgelopen 30 dagen · binnen 25 km")
                    .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                    .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                filters
                if let loadError = store.loadError { Text(loadError).foregroundStyle(.red) }
                if location.isLocating { ProgressView("Je huidige locatie ophalen…") }
                if location.isNaming { ProgressView("Locatienaam ophalen…") }
                if let message = location.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                if model.isLoading { ProgressView("Vogels in de omgeving ophalen…") }
                if let message = model.message { Text(message) }
                if model.isDemo {
                    Text("Voorbeelddata · geen live meldingen voor deze locatie")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(FieldGuideTheme.beige.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                }
                if !model.isLoading, model.loadedQuery != nil, rows.isEmpty {
                    Text(model.rows.isEmpty ? "Geen meldingen gevonden in dit gebied en tijdvak."
                         : "Geen soorten voor dit filter.")
                }
                ForEach(rows) { row in
                    NavigationLink(value: row.species) {
                        HStack(spacing: 16) {
                            PrimaryBirdArtwork(species: row.species).frame(width: 104, height: 104)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(row.species.dutchName).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(row.reportCount) meldingen")
                                    .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                    .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            SpeciesLogBadge(status: store.logStatus(for: row.id), speciesName: row.species.dutchName)
                        }.frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                    }.buttonStyle(.plain)
                }
                if let attribution = model.attribution {
                    Text(attribution).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                }
                Text("Recente meldingen geven geen garantie dat je een soort vandaag ziet; ongemelde soorten kunnen ook aanwezig zijn.")
                    .font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                Button { demo = false; location.useCurrentLocation() } label: {
                    Label("Gebruik huidige locatie", systemImage: "location").frame(minHeight: 44)
                }
                if !model.isDemo {
                    Button("Bekijk voorbeeldpagina") { demo = true }
                        .frame(minHeight: 44)
                }
            }.padding(20).padding(.bottom, 24)
        }
        .background(FieldGuideTheme.ivory)
        .toolbar(.hidden, for: .navigationBar)
        .task { if location.latitude == nil && !demo { location.useCurrentLocation() } }
        .task(id: queryKey) { if let query { await model.load(query: query, demo: demo) } }
        .task(id: demo) {
            if demo && location.latitude == nil {
                // Explicit fictional coordinate at 0/0, never presented as current GPS.
                await model.load(query: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: 25), demo: true)
            }
        }
        .refreshable { if let query { await model.load(query: query, demo: demo) } }
        .onDisappear { location.stop() }
    }

    private var filters: some View {
        HStack(spacing: 12) {
            ForEach(DiscoverFilter.allCases, id: \.self) { choice in
                Button { filter = choice } label: {
                    Group {
                        if choice == .all {
                            Image(systemName: "square.grid.2x2").font(.system(size: 18, weight: .light))
                        } else {
                            ZStack {
                                PupilFreeEye().stroke(lineWidth: 0.75)
                                if choice == .logged { Circle().frame(width: 5, height: 5) }
                            }.frame(width: 22, height: 14)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .foregroundStyle(filter == choice ? FieldGuideTheme.ivory : FieldGuideTheme.charcoal)
                    .background(filter == choice ? FieldGuideTheme.charcoal : FieldGuideTheme.beige, in: Circle())
                }
                .accessibilityLabel(choice.label)
                .accessibilityAddTraits(filter == choice ? [.isSelected] : [])
                .disabled(choice != .all && store.loadError != nil)
            }
            Spacer(minLength: 0)
        }
    }
}

struct PrimaryBirdArtwork: View {
    let species: Species
    var body: some View {
        Group {
            if UIImage(named: species.id + "-primary") != nil {
                Image(species.id + "-primary").resizable().scaledToFit()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "bird").font(.title2)
                    Text("Illustratie volgt").font(FieldGuideTheme.sans(11, relativeTo: .caption2))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FieldGuideTheme.beige.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Primaire illustratie van \(species.dutchName)")
    }
}

struct SpeciesLogBadge: View {
    let status: SpeciesLogStatus
    let speciesName: String
    var body: some View {
        Group {
            if status == .unavailable { Image(systemName: "questionmark") }
            else {
                ZStack {
                    PupilFreeEye().stroke(lineWidth: 0.75)
                    if status == .logged { Circle().frame(width: 5, height: 5) }
                }.frame(width: 22, height: 14)
            }
        }
        .foregroundStyle(status == .logged ? FieldGuideTheme.ivory : FieldGuideTheme.charcoal)
        .frame(width: FieldGuideTheme.roundControlDiameter, height: FieldGuideTheme.roundControlDiameter)
        .background(status == .logged ? FieldGuideTheme.khaki : FieldGuideTheme.beige, in: Circle())
        .accessibilityLabel("\(speciesName): \(status == .logged ? "gelogd" : status == .notLogged ? "nog niet gelogd" : "status onbekend")")
    }
}
