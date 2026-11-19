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
    @State private var showAddMenu = false
    private let addButtonDiameter: CGFloat = 72
    private var addButtonOverlap: CGFloat { addButtonDiameter * 0.30 }
    private let species = MockSpeciesRepository.kingfisher

    var body: some View {
        ZStack {
            content
                .opacity(observationNavigation.selection == nil && !showLiveSession && !showAddMenu ? 1 : 0)
                .allowsHitTesting(observationNavigation.selection == nil && !showLiveSession && !showAddMenu)
                .accessibilityHidden(observationNavigation.selection != nil || showLiveSession || showAddMenu)
            if showAddMenu {
                AddEntryView(isPresented: $showAddMenu)
            } else if showLiveSession {
                LiveSessionView(isPresented: $showLiveSession)
            } else if let observation = observationNavigation.selection {
                ObservationMapView(observation: observation, species: observationNavigation.species ?? species)
            }
        }
            .environmentObject(observationNavigation)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background((showAddMenu ? FieldGuideTheme.charcoal : FieldGuideTheme.ivory).ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: -addButtonOverlap) { bottomNavigation }
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

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            // Negative inset spacing lets habitat extend behind this reserved hit area.
            Color.clear.frame(height: addButtonOverlap).allowsHitTesting(false)
            if showAddMenu {
                Color.clear.frame(height: 60).allowsHitTesting(false)
            } else {
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
        }
        .overlay(alignment: .top) {
            Button {
                if showAddMenu { showAddMenu = false }
                else if store.activeSession != nil {
                    observationNavigation.selection = nil
                    showAddMenu = false
                    showLiveSession = true
                } else if observationNavigation.selection != nil { observationNavigation.selection = nil }
                else {
                    showAddMenu.toggle()
                }
            } label: {
                Group {
                    if store.activeSession != nil && !showAddMenu {
                        Image(systemName: "play").font(.system(size: 32, weight: .ultraLight))
                            .foregroundStyle(FieldGuideTheme.ivory)
                            .frame(width: 45, height: 45)
                    } else {
                        FinePlusMark()
                            .stroke(showAddMenu || observationNavigation.selection != nil ? FieldGuideTheme.charcoal : FieldGuideTheme.ivory,
                                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                            .rotationEffect(.degrees(showAddMenu || observationNavigation.selection != nil ? 45 : 0))
                            .frame(width: 45, height: 45)
                    }
                }
                    .frame(width: addButtonDiameter, height: addButtonDiameter)
                    .background(showAddMenu ? FieldGuideTheme.beige :
                        (store.activeSession != nil ? FieldGuideTheme.khaki :
                        (observationNavigation.selection == nil ? FieldGuideTheme.charcoal : FieldGuideTheme.selectedBeige)), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showAddMenu ? "Sluit toevoegopties" : (store.activeSession != nil ? "Open livesessie" : (observationNavigation.selection == nil ? "Open toevoegopties" : "Sluit waarneming")))
            .accessibilityHint(showAddMenu ? "Terug naar de vorige pagina" : (store.activeSession != nil ? "Terug naar de actieve vogelsessie" : (observationNavigation.selection == nil ? "Voeg een waarneming, sessie of doelstelling toe" : "Terug naar het overzicht van waarnemingen")))
        }
    }

    private func navigationItem(_ item: MainSection, symbol: String) -> some View {
        Button {
            observationNavigation.selection = nil
            showLiveSession = false
            showAddMenu = false
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
