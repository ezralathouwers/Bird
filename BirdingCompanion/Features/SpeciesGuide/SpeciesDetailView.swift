import SwiftUI
import SafariServices
import AVFoundation

struct SpeciesDetailView: View {
    let species: Species
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: SpeciesTab = .overview
    @State private var artworkPage = 0
    @State private var showObservation = false
    @State private var showImages = false
    @StateObject private var audio = SpeciesAudioModel()
    @Environment(\.speciesAudioIsAllowed) private var audioIsAllowed
    @Environment(\.scenePhase) private var scenePhase
    @State private var showRangeMap = false

    private var searchURL: URL {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "tbm", value: "isch"), URLQueryItem(name: "q", value: species.scientificName)]
        return components.url!
    }

    var body: some View {
        VStack(spacing: 0) {
            header.fixedSize(horizontal: false, vertical: true)
            Group {
            switch tab {
            case .overview:
                GeometryReader { viewport in
                    SpeciesArtworkCarousel(species: species, page: $artworkPage)
                        .frame(width: viewport.size.width, height: viewport.size.height)
                }
                .clipped()
            case .information:
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SpeciesDistributionMap(species: species, onExpand: { showRangeMap = true })
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        SpeciesFacts(species: species).padding(.horizontal, 20)
                    }
                    .padding(.top, 16).padding(.bottom, 24)
                }
            case .observations:
                ScrollView {
                    ObservationHistoryView(species: species, embedded: true, showsExport: false, prominentTotal: true)
                        .padding(.horizontal, 20).padding(.bottom, 24)
                }
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab == .information { HabitatFooter(species: species) }
        }
        .background(FieldGuideTheme.ivory)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showObservation) { ObservationForm(species: species) }
        .fullScreenCover(isPresented: $showRangeMap) { SpeciesRangeFullscreenView(species: species) }
        .sheet(isPresented: $showImages) {
            NavigationStack {
                SafariSearchView(url: searchURL).ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Google Afbeeldingen").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Sluiten") { showImages = false } } }
            }
        }
        .task(id: species.id) { await audio.prepare(for: species) }
        .task(id: species.id) {
            // Warm immutable range data on its own actor while Overview is shown.
            _ = try? await SpeciesRangeDataLoader.shared.load(speciesID: species.id)
        }
        .onDisappear { audio.leavePage() }
        .onChange(of: audioIsAllowed) { _, allowed in if !allowed { audio.stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { audio.stop() } }
        .onChange(of: showImages) { _, shown in if shown { audio.stop() } }
        .onChange(of: showObservation) { _, shown in if shown { audio.stop() } }
        .onChange(of: showRangeMap) { _, shown in if shown { audio.stop() } }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in audio.stop() }
        .alert("Geluid afspelen", isPresented: Binding(
            get: { audio.playbackError != nil },
            set: { if !$0 { audio.playbackError = nil } })) {
                Button("Sluiten", role: .cancel) { audio.playbackError = nil }
            } message: { Text(audio.playbackError ?? "") }
    }

    private var header: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    SpeciesBackButton { dismiss() }
                    Spacer(minLength: 0)
                    actions
                }
                heading
                SpeciesTabStrip(selection: $tab).padding(.top, 12)
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 4)
            .background(FieldGuideTheme.ivory)
    }

    private var heading: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(species.englishDisplayName)
                    .font(FieldGuideTheme.sans(15, relativeTo: .subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                SpeciesDetailTitle(text: species.dutchName)
                    .offset(y: 4) // Visual adjustment only: header/tab positions stay fixed.
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
            if audio.recording != nil {
                RoundAction(symbol: audio.isPlaying ? "stop" : "speaker.wave.2",
                            label: audio.isPlaying ? "Stop het geluid van \(species.dutchName)" : "Beluister \(species.dutchName)") {
                    audio.toggle()
                }
                .accessibilityValue(audio.isPlaying ? "Wordt herhaald" : "Gestopt")
            }
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
