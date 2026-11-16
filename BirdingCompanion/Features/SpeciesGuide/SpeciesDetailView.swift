import SwiftUI
import SafariServices

struct SpeciesDetailView: View {
    let species: Species
    @EnvironmentObject private var store: ObservationStore
    @State private var tab: SpeciesTab = .overview
    @State private var showObservation = false
    @State private var showImages = false
    @State private var showAudio = false

    private var searchURL: URL {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "tbm", value: "isch"), URLQueryItem(name: "q", value: species.scientificName)]
        return components.url!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { heading; Spacer(minLength: 0); actions }
                    VStack(alignment: .leading, spacing: 16) { heading; actions }
                }
                KingfisherArtworkCarousel()
                SpeciesTabStrip(selection: $tab)
                tabContent
            }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab == .overview { HabitatFooter() }
        }
        .background(FieldGuideTheme.ivory)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(FieldGuideTheme.ivory, for: .navigationBar)
        .sheet(isPresented: $showObservation) { ObservationForm(species: species) }
        .sheet(isPresented: $showImages) {
            NavigationStack {
                SafariSearchView(url: searchURL).ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Google Afbeeldingen").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Sluiten") { showImages = false } } }
            }
        }
        .alert("Geluid nog niet beschikbaar", isPresented: $showAudio) {
            Button("Sluiten", role: .cancel) {}
        } message: { Text("Er is nog geen geluidsopname met gecontroleerde gebruiksrechten toegevoegd.") }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(species.dutchName).font(FieldGuideTheme.speciesTitle)
                .fixedSize(horizontal: false, vertical: true)
            Text(species.englishName).font(FieldGuideTheme.sans(15, relativeTo: .subheadline)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            RoundAction(symbol: "speaker.wave.2", label: "Beluister de ijsvogel") { showAudio = true }
            RoundAction(symbol: "photo", label: "Zoek afbeeldingen van de ijsvogel op Google") { showImages = true }
            RoundAction(symbol: "plus", label: "Voeg een waarneming toe") { showObservation = true }
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch tab {
        case .overview: SpeciesFacts()
        case .distribution:
            Text("Verspreidingsinformatie volgt na broncontrole. De overzichtspagina bevat geen kaart.").font(FieldGuideTheme.sans(17, relativeTo: .body))
        case .observations: ObservationHistoryView(species: species, embedded: true)
        }
    }
}

private struct SafariSearchView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack { SpeciesDetailView(species: MockSpeciesRepository.kingfisher) }
        .environmentObject(ObservationStore(persistence: PreviewObservationPersistence()))
}

struct PreviewObservationPersistence: ObservationPersistence {
    func load() throws -> [Observation] { [] }
    func save(_ observations: [Observation]) throws {}
}
