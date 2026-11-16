import SwiftUI

private enum MainSection: String {
    case discover = "Ontdek", identify = "Identificeer", sessions = "Sessies", list = "Logboek"
}

struct CompanionRootView: View {
    @EnvironmentObject private var store: ObservationStore
    @StateObject private var observationNavigation = ObservationNavigation()
    @State private var section: MainSection = .discover
    @State private var speciesPath = ["kingfisher"]
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
                ObservationMapView(observation: observation, species: species)
            }
        }
            .environmentObject(observationNavigation)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FieldGuideTheme.ivory)
            .safeAreaInset(edge: .bottom, spacing: -addButtonOverlap) { bottomNavigation }
            .fullScreenCover(isPresented: $showObservation) { ObservationForm(species: species) }
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .discover:
            NavigationStack(path: $speciesPath) {
                List {
                    NavigationLink(species.dutchName, value: "kingfisher")
                }
                .navigationTitle("Ontdek")
                .navigationDestination(for: String.self) { _ in SpeciesDetailView(species: species) }
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
                        if LifelistRules().speciesIDs(in: store.observations).contains(species.id) {
                            Text("Lifelijst: \(species.dutchName)")
                        } else { Text("Nog geen bevestigde soorten op je lifelijst.") }
                        ObservationHistoryView(species: species, embedded: true)
                    }.padding(20)
                }.navigationTitle("Logboek")
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
                else { showObservation = true }
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
            .accessibilityHint(observationNavigation.selection == nil ? "Opent het formulier voor de huidige voorbeeldsoort, ijsvogel" : "Terug naar het overzicht van waarnemingen")
        }
    }

    private func navigationItem(_ item: MainSection, symbol: String) -> some View {
        Button { observationNavigation.selection = nil; section = item } label: {
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
