import SwiftUI

private enum MainSection: String {
    case discover = "Ontdek", identify = "Identificeer", sessions = "Sessies", list = "Logboek"
}

struct CompanionRootView: View {
    @EnvironmentObject private var store: ObservationStore
    @StateObject private var observationNavigation = ObservationNavigation()
    @State private var section: MainSection = .discover
    @State private var speciesPath: [Species] = []
    @StateObject private var discover = DiscoverViewModel()
    @State private var birdToLog: Species?
    @State private var showObservation = false
    private let addButtonDiameter: CGFloat = 72
    private var addButtonOverlap: CGFloat { addButtonDiameter * 0.30 }
    private let species = MockSpeciesRepository.kingfisher

    var body: some View {
        ZStack {
            content
                .opacity(observationNavigation.selection == nil ? 1 : 0)
                .allowsHitTesting(observationNavigation.selection == nil)
                .accessibilityHidden(observationNavigation.selection != nil)
            if let observation = observationNavigation.selection {
                ObservationMapView(observation: observation, species: observationNavigation.species ?? species)
            }
        }
            .environmentObject(observationNavigation)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FieldGuideTheme.ivory)
            .safeAreaInset(edge: .bottom, spacing: -addButtonOverlap) { bottomNavigation }
            .fullScreenCover(isPresented: $showObservation) {
                if let birdToLog { ObservationForm(species: birdToLog) }
                else { birdPicker }
            }
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .discover:
            NavigationStack(path: $speciesPath) {
                DiscoverView(model: discover)
                    .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
            }
        case .identify:
            NavigationStack {
                Text("Foto- en geluidsherkenning volgen in een volgende fase.")
                    .padding().navigationTitle("Identificeer")
            }
        case .sessions:
            NavigationStack {
                Text("Vogelsessies volgen in een volgende fase. Je losse waarnemingen vind je onder Logboek.")
                    .padding().navigationTitle("Sessies")
            }
        case .list:
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("\(LifelistRules().speciesIDs(in: store.observations).count) soorten op je lifelijst")
                        ForEach(DiscoverFixtures.catalog.filter { !store.observations(for: $0.id).isEmpty }) { bird in
                            Text(bird.dutchName).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                            ObservationHistoryView(species: bird, embedded: true,
                                showsExport: bird.id == DiscoverFixtures.catalog.first(where: { !store.observations(for: $0.id).isEmpty })?.id)
                        }
                        if store.observations.isEmpty {
                            ObservationHistoryView(species: species, embedded: true)
                        }
                    }.padding(20)
                }.navigationTitle("Logboek")
            }
        }
    }

    private var birdPicker: some View {
        NavigationStack {
            List(DiscoverFixtures.catalog) { bird in
                Button { birdToLog = bird } label: {
                    HStack(spacing: 12) {
                        PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                        Text(bird.dutchName)
                    }
                }
            }
            .navigationTitle("Kies een vogel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { showObservation = false }
                }
            }
        }
    }

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            // Negative inset spacing lets habitat extend behind this reserved hit area.
            Color.clear.frame(height: addButtonOverlap).allowsHitTesting(false)
            HStack(alignment: .center, spacing: 0) {
                navigationItem(.discover, symbol: "binoculars")
                navigationItem(.identify, symbol: "viewfinder")
                Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                    .allowsHitTesting(false)
                navigationItem(.sessions, symbol: "clock")
                navigationItem(.list, symbol: "bird")
            }
            .foregroundStyle(FieldGuideTheme.charcoal)
            .padding(.top, 4)
            .background(FieldGuideTheme.navigationWhite.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(FieldGuideTheme.charcoal).frame(height: 0.5) }
        }
        .overlay(alignment: .top) {
            Button {
                if observationNavigation.selection != nil { observationNavigation.selection = nil }
                else {
                    birdToLog = section == .discover ? speciesPath.last : nil
                    showObservation = true
                }
            } label: {
                FinePlusMark()
                    .stroke(observationNavigation.selection == nil ? FieldGuideTheme.ivory : FieldGuideTheme.charcoal,
                            style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                    .rotationEffect(.degrees(observationNavigation.selection == nil ? 0 : 45))
                    .frame(width: 45, height: 45)
                    .frame(width: addButtonDiameter, height: addButtonDiameter)
                    .background(observationNavigation.selection == nil ? FieldGuideTheme.charcoal : FieldGuideTheme.selectedBeige, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(observationNavigation.selection == nil ? "Voeg een waarneming toe" : "Sluit waarneming")
            .accessibilityHint(observationNavigation.selection == nil ? "Kies een soort en voeg een waarneming toe" : "Terug naar het overzicht van waarnemingen")
        }
    }

    private func navigationItem(_ item: MainSection, symbol: String) -> some View {
        Button {
            observationNavigation.selection = nil
            if item == .discover { speciesPath.removeAll() }
            section = item
        } label: {
            Image(systemName: symbol)
                .font(.system(size: item == .discover || item == .list ? 21.6 : 24, weight: .ultraLight))
                .offset(x: item == .identify ? -6 : (item == .sessions ? 6 : 0))
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(item.rawValue)
        .accessibilityAddTraits(section == item ? [.isSelected] : [])
        .opacity(section == item ? 1 : 0.75)
    }
}

// Explicit hairline glyph: the circle behind this mark intentionally has no stroke.
private struct FinePlusMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
