import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var store: ObservationStore
    @ObservedObject var model: DiscoverViewModel
    @StateObject private var location = ObservationLocationModel()
    @State private var filter: DiscoverFilter = .all
    @State private var demo = false
    @State private var showSearch = false
    @State private var showCatalogSources = false
    @State private var catalogQuery = ""
    @FocusState private var searchFocused: Bool
    var catalog: [Species] = SpeciesGuideCatalog.species
    var catalogIsComplete = false

    private var queryKey: String {
        guard let latitude = location.latitude, let longitude = location.longitude else { return "no-location" }
        return "\(latitude),\(longitude),\(demo)"
    }
    private var query: DiscoverQuery? {
        guard let latitude = location.latitude, let longitude = location.longitude else { return nil }
        return DiscoverQuery(latitude: latitude, longitude: longitude, now: Date(), radiusKilometers: 10)
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
                Text(showSearch ? "Zoek een vogelsoort" : "Vandaag in \(locationTitle)")
                    .modifier(LargeHeadingStyle(size: 44.2))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 60)
                    .padding(.bottom, 6)
                if showSearch { catalogSearch } else { nearbyContent }
            }.padding(20).padding(.bottom, 24)
        }
        .background(FieldGuideTheme.ivory)
        .overlay(alignment: .topLeading) {
            Button { showCatalogSources = true } label: {
                Image(systemName: "info.circle").font(.system(size: 22, weight: .light))
                    .foregroundStyle(FieldGuideTheme.mutedIcon)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }.accessibilityLabel("Info").padding(.leading, 20).padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            Button { showSearch.toggle() } label: {
                Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    .font(.system(size: 22, weight: .light)).frame(width: 44, height: 44)
                    .background(FieldGuideTheme.beige.opacity(0.4), in: Circle())
            }.accessibilityLabel(showSearch ? "Sluit soortenzoeker" : "Zoek alle vogelsoorten")
                .padding(.trailing, 20).padding(.top, 8)
        }
        .onChange(of: showSearch) { _, shown in
            searchFocused = shown
            if !shown { catalogQuery = "" }
        }
        .sheet(isPresented: $showCatalogSources) { SpeciesCatalogSourcesView() }
        .toolbar(.hidden, for: .navigationBar)
        .task { if location.latitude == nil && !demo { location.useCurrentLocation() } }
        .task(id: queryKey) { if let query { await model.load(query: query, demo: demo) } }
        .task(id: demo) {
            if demo && location.latitude == nil {
                // Explicit fictional coordinate at 0/0, never presented as current GPS.
                await model.load(query: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: 10), demo: true)
            }
        }
        .refreshable { if let query { await model.load(query: query, demo: demo) } }
        .onDisappear { location.stop() }
    }

    @ViewBuilder private var nearbyContent: some View {
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
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        NavigationLink(value: row.species) {
                            HStack(spacing: 12) {
                                PrimaryBirdArtwork(species: row.species).frame(width: 64, height: 64)
                                SerifText(row.species.dutchName, size: 20, relativeTo: .title3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                SpeciesLogBadge(status: store.logStatus(for: row.id), speciesName: row.species.dutchName, diameter: 22)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if index < rows.count - 1 {
                            Rectangle().fill(FieldGuideTheme.charcoal.opacity(0.10)).frame(height: 0.5)
                                .accessibilityHidden(true)
                        }
                    }
                }
                if let attribution = model.attribution {
                    Text(attribution).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                }
                Button { demo = false; location.useCurrentLocation() } label: {
                    Label("Gebruik huidige locatie", systemImage: "location").frame(minHeight: 44)
                }
                if !model.isDemo {
                    Button("Bekijk voorbeeldpagina") { demo = true }
                        .frame(minHeight: 44)
                }
    }

    private var catalogSearch: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            TextField("Zoek een vogel", text: $catalogQuery)
                .modifier(RoundedSearchField()).autocorrectionDisabled()
                .focused($searchFocused)
                .accessibilityLabel("Zoek alle soorten op Nederlandse, Engelse of wetenschappelijke naam")
            let results = SpeciesCatalogSearch.results(for: catalogQuery, in: catalog)
            if results.isEmpty { Text("Geen soorten gevonden.") }
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, bird in
                    NavigationLink(value: bird) {
                        HStack(spacing: 12) {
                            PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                            VStack(alignment: .leading, spacing: 6) {
                                SerifText(bird.dutchName, size: 16, relativeTo: .body)
                                Text(bird.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            SpeciesLogBadge(status: store.logStatus(for: bird.id), speciesName: bird.dutchName, diameter: 22)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if index < results.count - 1 {
                        Rectangle().fill(FieldGuideTheme.charcoal.opacity(0.10)).frame(height: 0.5)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
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

// Reviewed source orientation. New primary assets must face right or be listed here.
// Keep this shared by the guide, lists, forms, picker and map markers.
struct PrimaryBirdImage: View {
    let species: Species
    private var sourceFacesLeft: Bool {
        ["sample-parus-major", "sample-cyanistes-caeruleus", "sample-alcedo-atthis"].contains(species.id)
    }
    var body: some View {
        Image(SpeciesMediaRole.classic.assetName(for: species)).resizable().scaledToFit()
            .scaleEffect(x: sourceFacesLeft ? -1 : 1, y: 1)
    }
}

struct PrimaryBirdArtwork: View {
    let species: Species
    var body: some View {
        Group {
            if UIImage(named: SpeciesMediaRole.classic.assetName(for: species)) != nil {
                PrimaryBirdImage(species: species)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "bird").font(.title2)
                    Text("Illustratie volgt").font(FieldGuideTheme.sans(11, relativeTo: .caption2))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Primaire illustratie van \(species.dutchName)")
    }
}

struct SpeciesLogBadge: View {
    let status: SpeciesLogStatus
    let speciesName: String
    var diameter: CGFloat = FieldGuideTheme.roundControlDiameter
    private var scale: CGFloat { diameter / FieldGuideTheme.roundControlDiameter }
    var body: some View {
        Group {
            if status == .unavailable { Image(systemName: "questionmark").font(.system(size: 17 * scale)) }
            else {
                ZStack {
                    PupilFreeEye().stroke(lineWidth: 0.75 * scale)
                    if status == .logged { Circle().frame(width: 5 * scale, height: 5 * scale) }
                }.frame(width: 22 * scale, height: 14 * scale)
            }
        }
        .foregroundStyle(status == .logged ? FieldGuideTheme.ivory : FieldGuideTheme.charcoal)
        .frame(width: diameter, height: diameter)
        .background(status == .logged ? FieldGuideTheme.khaki : FieldGuideTheme.beige, in: Circle())
        .accessibilityLabel("\(speciesName): \(status == .logged ? "gelogd" : status == .notLogged ? "nog niet gelogd" : "status onbekend")")
    }
}
