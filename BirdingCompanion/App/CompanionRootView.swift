import SwiftUI

struct CompanionRootView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var speciesPath = ["kingfisher"]
    private let species = MockSpeciesRepository.kingfisher
    var body: some View {
        TabView {
            NavigationStack(path: $speciesPath) {
                List {
                    NavigationLink(species.dutchName, value: "kingfisher")
                }
                .navigationTitle("Vogels van de wereld")
                .navigationDestination(for: String.self) { _ in SpeciesDetailView(species: species) }
            }
            .tabItem { Label("Soort", systemImage: "bird") }
            NavigationStack {
                ScrollView { ObservationHistoryView(species: species) }.navigationTitle("Waarneming")
            }.tabItem { Label("Waarneming", systemImage: "book") }
            NavigationStack {
                Text("Locaties volgen in een volgende fase.").padding().navigationTitle("Locaties")
            }.tabItem { Label("Locaties", systemImage: "mappin.and.ellipse") }
            NavigationStack {
                List {
                    if LifelistRules().speciesIDs(in: store.observations).contains(species.id) {
                        Text(species.dutchName)
                    } else { Text("Nog geen bevestigde soorten op je lifelijst.") }
                    if let loadError = store.loadError { Text(loadError).foregroundStyle(.red) }
                }.navigationTitle("Lifelijst")
            }.tabItem { Label("Lifelijst", systemImage: "checklist") }
            NavigationStack {
                Text("Birding Companion · Prototype\nOffline waarnemingen, mocksoort en tijdelijke illustratieplaatsen. Geen iCloud-synchronisatie.\nAfbeeldingen zoeken vereist internet; Safari toont verbindingsfouten en biedt openen in de browser.")
                    .padding().navigationTitle("Info")
            }.tabItem { Label("Info", systemImage: "info.circle") }
        }
    }
}
