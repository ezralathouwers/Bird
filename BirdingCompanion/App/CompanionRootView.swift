import SwiftUI

private enum MainSection: String {
    case discover = "Ontdek", identify = "Identificeer", sessions = "Sessies", list = "Logboek"
}

struct CompanionRootView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var section: MainSection = .discover
    @State private var speciesPath = ["kingfisher"]
    @State private var showObservation = false
    private let species = MockSpeciesRepository.kingfisher

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FieldGuideTheme.ivory)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomNavigation }
            .sheet(isPresented: $showObservation) { ObservationForm(species: species) }
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
        HStack(alignment: .center, spacing: 0) {
            navigationItem(.discover, symbol: "binoculars")
            navigationItem(.identify, symbol: "viewfinder")
            Button { showObservation = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .ultraLight))
                    .frame(width: 48, height: 48)
                    .background(Circle().stroke(FieldGuideTheme.beige, lineWidth: 0.5))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Voeg een waarneming toe")
            .accessibilityHint("Opent het formulier voor de huidige voorbeeldsoort, ijsvogel")
            navigationItem(.sessions, symbol: "clock")
            navigationItem(.list, symbol: "list.bullet")
        }
        .foregroundStyle(FieldGuideTheme.taupe)
        .padding(.top, 4)
        .background(FieldGuideTheme.ivory.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(FieldGuideTheme.beige).frame(height: 0.5) }
    }

    private func navigationItem(_ item: MainSection, symbol: String) -> some View {
        Button { section = item } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 20, weight: .ultraLight))
                Text(item.rawValue).font(FieldGuideTheme.sans(10, relativeTo: .caption2))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(section == item ? [.isSelected] : [])
        .opacity(section == item ? 1 : 0.75)
    }
}
