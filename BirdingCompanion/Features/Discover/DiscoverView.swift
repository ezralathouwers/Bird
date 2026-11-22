import SwiftUI
import UIKit

struct DiscoverView: View {
    @EnvironmentObject private var store: ObservationStore
    @ObservedObject var model: DiscoverViewModel
    @StateObject private var location = ObservationLocationModel(locationPolicy: .browsing)
    @State private var filter: DiscoverFilter = .all
    @State private var demo = false
    @State private var showSearch = false
    @State private var showCatalogSources = false
    @State private var showBackups = false
    @State private var showEBirdConnection = false
    @State private var connectionRevision = UUID()
    @State private var catalogQuery = ""
    @FocusState private var searchFocused: Bool
    var catalog: [Species] = SpeciesGuideCatalog.species
    var catalogIsComplete = false

    private var queryKey: String {
        guard let latitude = location.latitude, let longitude = location.longitude else { return "no-location" }
        return "\(latitude),\(longitude),\(demo),\(connectionRevision)"
    }
    private var query: DiscoverQuery? {
        guard let latitude = location.latitude, let longitude = location.longitude else { return nil }
        return DiscoverQuery(latitude: latitude, longitude: longitude, now: Date(), radiusKilometers: DiscoverQuery.nearbyRadiusKilometers)
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
        Group {
            if showSearch {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        heading
                        BirdTextField("Zoek een vogel", text: $catalogQuery)
                            .modifier(RoundedSearchField()).autocorrectionDisabled()
                            .focused($searchFocused)
                            .accessibilityLabel("Zoek alle soorten op Nederlandse, Engelse of wetenschappelijke naam")
                    }
                    .padding(20)
                    .background(FieldGuideTheme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                    ScrollView {
                        catalogSearch.padding(.horizontal, 20).padding(.bottom, 94)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            } else {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        heading
                        filters
                    }
                    .padding(20)
                    .background(FieldGuideTheme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            nearbyContent
                        }.padding(.horizontal, 20).padding(.bottom, 94)
                    }
                    .refreshable { if let query { await model.load(query: query, demo: demo) } }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FieldGuideTheme.ivory)
        .overlay(alignment: .topLeading) {
            HStack(spacing: 0) {
                Button { showCatalogSources = true } label: {
                    Image(systemName: "info.circle").font(.system(size: 22, weight: .ultraLight))
                        .frame(width: 44, height: 44, alignment: .leading).contentShape(Rectangle())
                }.accessibilityLabel("Info")
                Button { showBackups = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 22, weight: .ultraLight))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Gegevens en back-ups")
            }.buttonStyle(.plain).foregroundStyle(FieldGuideTheme.mutedIcon)
                .padding(.leading, 20).padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            Button { showSearch.toggle() } label: {
                Group {
                    if showSearch { Image(systemName: "xmark").font(.system(size: 22, weight: .ultraLight)) }
                    else { FineSearchMark().stroke(style: FieldGuideTheme.navigationStroke).frame(width: 22, height: 22) }
                }.frame(width: 44, height: 44)
                    .background(FieldGuideTheme.searchControlBackground, in: Circle())
            }.accessibilityLabel(showSearch ? "Sluit soortenzoeker" : "Zoek alle vogelsoorten")
                .padding(.trailing, 20).padding(.top, 8)
        }
        .onChange(of: showSearch) { _, shown in
            searchFocused = shown
            if !shown { catalogQuery = "" }
        }
        .fullScreenCover(isPresented: $showBackups) {
            NavigationStack { DataBackupsView().toolbar(.hidden, for: .navigationBar) }
        }
        .sheet(isPresented: $showCatalogSources) { SpeciesCatalogSourcesView() }
        .sheet(isPresented: $showEBirdConnection) {
            EBirdConnectionView(query: query) {
                model.reset()
                demo = false
                connectionRevision = UUID()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { if location.latitude == nil && !demo { location.useCurrentLocation() } }
        .task(id: queryKey) { if let query { await model.load(query: query, demo: demo) } }
        .task(id: demo) {
            if demo && location.latitude == nil {
                // Explicit fictional coordinate at 0/0, never presented as current GPS.
                await model.load(query: DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: DiscoverQuery.nearbyRadiusKilometers), demo: true)
            }
        }
        .onDisappear { location.stop() }
    }

    private var heading: some View {
        PageHeading(text: showSearch ? "Zoek een vogelsoort" : "Vandaag in \(locationTitle)")
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 60)
            .padding(.bottom, 6)
    }

    @ViewBuilder private var nearbyContent: some View {
                if let loadError = store.loadError { Text(loadError).foregroundStyle(.red) }
                if location.isLocating { ProgressView("Je huidige locatie ophalen…") }
                if location.isNaming { ProgressView("Locatienaam ophalen…") }
                if let message = location.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                if model.isLoading { ProgressView("Vogels in de omgeving ophalen…") }
                if let message = model.message { Text(message) }
                if model.needsConnection {
                    Button("Verbind eBird") { showEBirdConnection = true }.frame(minHeight: 44)
                } else if model.message != nil {
                    Button("Probeer opnieuw") {
                        if let query { Task { await model.load(query: query, demo: demo) } }
                    }.frame(minHeight: 44)
                }
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
                        HStack(spacing: 0) {
                            let status = store.logStatus(for: row.id)
                            NavigationLink(value: row.species) {
                                DiscoverSpeciesRow(species: row.species, status: status, showsBadge: false)
                            }.buttonStyle(.plain)
                            if status == .notLogged, let url = row.observationURL {
                                Link(destination: url) {
                                    SpeciesLogBadge(status: status, speciesName: row.species.dutchName, diameter: 22)
                                        .frame(width: 44, height: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("Open eBird-waarneming van \(row.species.dutchName)")
                            } else {
                                SpeciesLogBadge(status: status, speciesName: row.species.dutchName, diameter: 22).frame(width: 44, height: 44)
                            }
                        }
                        if index < rows.count - 1 {
                            Rectangle().fill(FieldGuideTheme.charcoal.opacity(0.10)).frame(height: 0.5)
                                .accessibilityHidden(true)
                        }
                    }
                }
                if let attribution = model.attribution {
                    Text(attribution).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Button { demo = false; location.useCurrentLocation() } label: {
                        Label("Gebruik huidige locatie", systemImage: "location").frame(minHeight: 44)
                    }
                    Button("Instellingen lokale meldingen") { showEBirdConnection = true }.frame(minHeight: 44).opacity(0.5)
                }

    }

    private var catalogSearch: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            let results = SpeciesCatalogSearch.results(for: catalogQuery, in: catalog)
            if results.isEmpty { Text("Geen soorten gevonden.") }
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, bird in
                    NavigationLink(value: bird) {
                        DiscoverSpeciesRow(species: bird, status: store.logStatus(for: bird.id))
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
        HStack(spacing: 8) {
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

// One row layout for nearby species and worldwide search results.
private struct DiscoverSpeciesRow: View {
    let species: Species
    let status: SpeciesLogStatus
    var showsBadge = true

    var body: some View {
        HStack(spacing: 12) {
            PrimaryBirdArtwork(species: species).frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                SerifText(species.dutchName, size: 16, relativeTo: .body)
                Text(species.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsBadge { SpeciesLogBadge(status: status, speciesName: species.dutchName, diameter: 22) }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// Explicit paragraph metrics reduce the custom font's native line height.
// SwiftUI's tight font leading alone does not give an exact baseline distance.
struct PageHeading: UIViewRepresentable {
    let text: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44.2

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.isAccessibilityElement = true
        label.accessibilityTraits = [.staticText, .header]
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let baseFont = UIFont(name: "DMSans-9ptRegular", size: size) ?? .systemFont(ofSize: size)
        let descriptor = baseFont.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium]
        ])
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = size * 1.08
        paragraph.maximumLineHeight = size * 1.08
        paragraph.lineBreakMode = .byWordWrapping
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont(descriptor: descriptor, size: size),
            .foregroundColor: UIColor(FieldGuideTheme.charcoal),
            .kern: size * -0.005,
            .paragraphStyle: paragraph
        ])
        label.accessibilityLabel = text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
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
