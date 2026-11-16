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
                    SpeciesTabStrip(selection: $tab).padding(.horizontal, 20)
                    if tab == .distribution {
                        SpeciesDistributionMap(species: species)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 8)
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 0) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .light))
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel("Terug naar Ontdek")
                    Spacer(minLength: 0)
                    actions
                }
                heading
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 16)
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
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 12) {
                Text(species.englishName)
                    .font(FieldGuideTheme.sans(15, relativeTo: .subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                logStatusBadge
            }
            Text(species.dutchName).font(FieldGuideTheme.speciesTitle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(FieldGuideTheme.charcoal)
    }

    private var logStatusBadge: some View {
        let status = store.logStatus(for: species.id)
        let symbol: String
        let label: String
        let background: Color
        let foreground: Color
        switch status {
        case .logged:
            symbol = "eye"; label = "Gelogd"
            background = FieldGuideTheme.khaki; foreground = FieldGuideTheme.ivory
        case .notLogged:
            symbol = "eye-outline"; label = "Nog niet gelogd"
            background = FieldGuideTheme.beige; foreground = FieldGuideTheme.charcoal
        case .unavailable:
            symbol = "questionmark"; label = "Status onbekend"
            background = FieldGuideTheme.beige; foreground = FieldGuideTheme.charcoal
        }
        return Group {
            if status == .notLogged {
                PupilFreeEye().stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .frame(width: 22, height: 14)
            } else {
                Image(systemName: symbol).font(.system(size: 18, weight: .light))
            }
        }
            .foregroundStyle(foreground)
            .frame(width: FieldGuideTheme.roundControlDiameter, height: FieldGuideTheme.roundControlDiameter)
            .background(background, in: Circle())
            .accessibilityLabel("\(species.dutchName): \(label)")
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
