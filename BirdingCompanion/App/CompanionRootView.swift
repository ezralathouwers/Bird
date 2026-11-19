import SwiftUI

private enum MainSection: String {
    case discover = "Ontdek", identify = "Identificeer", sessions = "Sessies", goals = "Doelstellingen", countries = "Landen", list = "Logboek"
}

struct CompanionRootView: View {
    @EnvironmentObject private var store: ObservationStore
    @StateObject private var sessionLogger = SessionLiveLogger()
    @State private var showLiveSession = false
    @StateObject private var observationNavigation = ObservationNavigation()
    @State private var section: MainSection = .discover
    @State private var speciesPath: [Species] = []
    @State private var logbookPath: [Species] = []
    @StateObject private var discover = DiscoverViewModel()
    @State private var birdToLog: Species?
    @State private var showObservation = false
    private let addButtonDiameter: CGFloat = 72
    private var addButtonOverlap: CGFloat { addButtonDiameter * 0.30 }
    private let species = MockSpeciesRepository.kingfisher

    var body: some View {
        ZStack {
            content
                .opacity(observationNavigation.selection == nil && !showLiveSession ? 1 : 0)
                .allowsHitTesting(observationNavigation.selection == nil && !showLiveSession)
                .accessibilityHidden(observationNavigation.selection != nil || showLiveSession)
            if showLiveSession {
                LiveSessionView(isPresented: $showLiveSession)
            } else if let observation = observationNavigation.selection {
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
            .environmentObject(sessionLogger)
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
                SessionsView(showLive: $showLiveSession)
            }
        case .goals:
            NavigationStack { GoalsView() }
        case .countries:
            NavigationStack { CountriesView() }
        case .list:
            NavigationStack(path: $logbookPath) {
                LogbookView()
                    .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
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
                navigationItem(.sessions, symbol: "clock")
                Color.clear.frame(minWidth: 44, maxWidth: .infinity, minHeight: 56)
                    .allowsHitTesting(false)
                navigationItem(.goals, symbol: "checklist")
                navigationItem(.countries, symbol: "globe")
                navigationItem(.list, symbol: "bird")
            }
            .foregroundStyle(FieldGuideTheme.charcoal)
            .padding(.top, 4)
            .background(FieldGuideTheme.navigationWhite.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(FieldGuideTheme.charcoal).frame(height: 0.5) }
        }
        .overlay(alignment: .top) {
            Button {
                if store.activeSession != nil {
                    observationNavigation.selection = nil
                    showLiveSession = true
                } else if observationNavigation.selection != nil { observationNavigation.selection = nil }
                else {
                    switch section {
                    case .discover: birdToLog = speciesPath.last
                    case .list: birdToLog = logbookPath.last
                    default: birdToLog = nil
                    }
                    showObservation = true
                }
            } label: {
                Group {
                    if store.activeSession != nil {
                        Image(systemName: "play").font(.system(size: 32, weight: .ultraLight))
                            .foregroundStyle(FieldGuideTheme.ivory)
                            .frame(width: 45, height: 45)
                    } else {
                        FinePlusMark()
                            .stroke(observationNavigation.selection == nil ? FieldGuideTheme.ivory : FieldGuideTheme.charcoal,
                                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                            .rotationEffect(.degrees(observationNavigation.selection == nil ? 0 : 45))
                            .frame(width: 45, height: 45)
                    }
                }
                    .frame(width: addButtonDiameter, height: addButtonDiameter)
                    .background(store.activeSession != nil ? FieldGuideTheme.khaki :
                        (observationNavigation.selection == nil ? FieldGuideTheme.charcoal : FieldGuideTheme.selectedBeige), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.activeSession != nil ? "Open livesessie" : (observationNavigation.selection == nil ? "Voeg een waarneming toe" : "Sluit waarneming"))
            .accessibilityHint(store.activeSession != nil ? "Terug naar de actieve vogelsessie" : (observationNavigation.selection == nil ? "Kies een soort en voeg een waarneming toe" : "Terug naar het overzicht van waarnemingen"))
        }
    }

    private func navigationItem(_ item: MainSection, symbol: String) -> some View {
        Button {
            observationNavigation.selection = nil
            showLiveSession = false
            if item == .discover { speciesPath.removeAll() }
            if item == .list { logbookPath.removeAll() }
            section = item
        } label: {
            Image(systemName: symbol)
                .font(.system(size: item == .discover ? 22.032 : (item == .list ? 21.6 : 24), weight: .ultraLight))
                .offset(x: item == .identify ? -6 : 0)
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(item.rawValue)
        .accessibilityAddTraits(section == item ? [.isSelected] : [])
        .foregroundStyle(section == item ? FieldGuideTheme.khaki : FieldGuideTheme.charcoal)
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
