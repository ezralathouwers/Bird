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
    private let addButtonDiameter: CGFloat = 64
    // The button's center (and plus crossbar) sits on the navigation's top edge.
    private var addButtonOverlap: CGFloat { addButtonDiameter / 2 }
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
                IdentificationView(isVisible: section == .identify && !showAddMenu && !showLiveSession && observationNavigation.selection == nil)
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
                GeometryReader { geometry in
                    // Equal slots within each group; keep 44-point targets on
                    // small phones and reserve a wider gap around the plus.
                    let centerGap = max(56, min(84, geometry.size.width - 6 * 44))
                    HStack(spacing: centerGap) {
                        HStack(spacing: 0) {
                            navigationItem(.discover, symbol: "binoculars")
                            navigationItem(.identify, symbol: "viewfinder")
                            navigationItem(.sessions, symbol: "clock")
                        }.frame(maxWidth: .infinity)
                        HStack(spacing: 0) {
                            navigationItem(.goals, symbol: "checklist")
                            navigationItem(.countries, symbol: "globe")
                            navigationItem(.list, symbol: "bird")
                        }.frame(maxWidth: .infinity)
                    }
                }
                // Bound the reader so safeAreaInset cannot consume the page.
                .frame(height: 56)
                .padding(.top, 4)
                .background(FieldGuideTheme.navigationWhite.ignoresSafeArea(edges: .bottom))
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
                            .frame(width: 40, height: 40)
                    } else {
                        FinePlusMark()
                            .stroke(showAddMenu || observationNavigation.selection != nil ? FieldGuideTheme.charcoal : FieldGuideTheme.ivory,
                                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                            .rotationEffect(.degrees(showAddMenu || observationNavigation.selection != nil ? 45 : 0))
                            .frame(width: 40, height: 40)
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
            Group {
                if item == .goals {
                    ZStack {
                        GoalListMark().stroke(style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
                        GoalCheckMark().stroke(FieldGuideTheme.charcoal,
                                               style: StrokeStyle(lineWidth: 0.85, lineCap: .round, lineJoin: .round))
                    }.frame(width: 24, height: 24)
                } else if item == .countries {
                    SimpleGlobeMark().stroke(style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: item == .discover ? 22.032 : (item == .list ? 21.6 : 24), weight: .ultraLight))
                }
            }
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.rawValue)
        .accessibilityAddTraits(section == item ? [.isSelected] : [])
        .foregroundStyle(section == item ? FieldGuideTheme.navigationOlive : FieldGuideTheme.charcoal)
    }
}

// Open circles, including the checked first item: no filled status dot.
private struct GoalListMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for y in [7.5, 16.5] {
            path.addEllipse(in: CGRect(x: 1.3, y: y - 3.1, width: 6.2, height: 6.2))
            path.move(to: CGPoint(x: 11, y: y))
            path.addLine(to: CGPoint(x: 23, y: y))
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

private struct GoalCheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 2.3, y: 7.5))
        path.addLine(to: CGPoint(x: 4.1, y: 9))
        path.addLine(to: CGPoint(x: 6.6, y: 5.7))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

// Curved meridians only; omit the straight vertical center line.
private struct SimpleGlobeMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 1, y: 1, width: 22, height: 22))
        path.addEllipse(in: CGRect(x: 8, y: 1, width: 8, height: 22))
        path.move(to: CGPoint(x: 1, y: 12))
        path.addLine(to: CGPoint(x: 23, y: 12))
        path.move(to: CGPoint(x: 2.2, y: 7))
        path.addQuadCurve(to: CGPoint(x: 21.8, y: 7), control: CGPoint(x: 12, y: 10))
        path.move(to: CGPoint(x: 2.2, y: 17))
        path.addQuadCurve(to: CGPoint(x: 21.8, y: 17), control: CGPoint(x: 12, y: 14))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
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
