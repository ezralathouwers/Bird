import SwiftUI
import SafariServices

struct SpeciesDetailView: View {
    let species: Species
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: SpeciesTab = .overview
    @State private var artworkPage = 0
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
            switch tab {
            case .overview:
                SpeciesArtworkCarousel(species: species, page: $artworkPage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .information:
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SpeciesFacts(species: species).padding(.horizontal, 20)
                        SpeciesDistributionMap(species: species)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 16)
                }
            case .observations:
                ScrollView {
                    ObservationHistoryView(species: species, embedded: true, showsExport: false, prominentTotal: true)
                        .padding(.horizontal, 20).padding(.bottom, 24)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab == .information { HabitatFooter(species: species) }
        }
        .background(FieldGuideTheme.ivory)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .light))
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel("Terug")
                    Spacer(minLength: 0)
                    actions
                }
                heading
                SpeciesTabStrip(selection: $tab).padding(.top, 12)
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 4)
            .background(FieldGuideTheme.ivory)
        }
        .fullScreenCover(isPresented: $showObservation) { ObservationForm(species: species) }
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(species.englishDisplayName)
                    .font(FieldGuideTheme.sans(15, relativeTo: .subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                SpeciesDetailTitle(text: species.dutchName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            logStatusBadge.padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(FieldGuideTheme.charcoal)
    }

    private var logStatusBadge: some View {
        SpeciesLogBadge(status: store.logStatus(for: species.id), speciesName: species.dutchName)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            RoundAction(symbol: "speaker.wave.2", label: "Beluister \(species.dutchName)") { showAudio = true }
            RoundAction(symbol: "photo", label: "Zoek afbeeldingen van \(species.dutchName) op Google") { showImages = true }
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
