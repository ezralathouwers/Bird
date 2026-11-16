import SwiftUI
import SafariServices

struct SpeciesDetailView: View {
    let species: Species
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
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
        Group {
            if tab != .overview {
                VStack(spacing: 16) {
                    heading.padding(.horizontal, 20).padding(.top, 4)
                    SpeciesTabStrip(selection: $tab).padding(.horizontal, 20)
                    if tab == .distribution {
                        SpeciesDistributionMap(species: species)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 32)
                    } else {
                        ScrollView {
                            ObservationHistoryView(species: species, embedded: true, showsExport: false, prominentTotal: true)
                                .padding(.horizontal, 20).padding(.bottom, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heading
                        KingfisherArtworkCarousel()
                        SpeciesTabStrip(selection: $tab)
                        SpeciesFacts()
                    }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 20)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab == .overview { HabitatFooter() }
        }
        .background(FieldGuideTheme.ivory)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .light))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Terug naar Ontdek")
                .offset(y: 4)
            }
            ToolbarItem(placement: .topBarTrailing) { actions.offset(y: 4) }
        }
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
            Text(species.englishName)
                .font(FieldGuideTheme.sans(15, relativeTo: .subheadline))
                .fixedSize(horizontal: false, vertical: true)
            Text(species.dutchName).font(FieldGuideTheme.speciesTitle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(FieldGuideTheme.charcoal)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            RoundAction(symbol: "speaker.wave.2", label: "Beluister de ijsvogel") { showAudio = true }
            RoundAction(symbol: "photo", label: "Zoek afbeeldingen van de ijsvogel op Google") { showImages = true }
            RoundAction(symbol: "plus", label: "Voeg een waarneming toe") { showObservation = true }
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
        .environmentObject(ObservationNavigation())
}

struct PreviewObservationPersistence: ObservationPersistence {
    func load() throws -> [Observation] { [] }
    func save(_ observations: [Observation]) throws {}
}
