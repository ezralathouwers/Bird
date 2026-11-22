import SwiftUI

private enum AddDestination: String, Identifiable {
    case observation, session, goal
    var id: String { rawValue }
}

struct AddEntryView: View {
    @Binding var isPresented: Bool
    var onLiveStarted: () -> Void = {}
    @State private var destination: AddDestination?
    @State private var startedLive = false
    var body: some View {
        GeometryReader { geometry in
            // Reserve a separate lower area around the floating close button.
            let bottomClearance: CGFloat = 180
            let choiceHeight = max(96, (geometry.size.height - bottomClearance - 1) / 3)
            ScrollView {
                VStack(spacing: 0) {
                    choice("Waarneming", accessibilityLabel: "Waarneming toevoegen", destination: .observation,
                           height: choiceHeight)
                    separator
                    choice("Sessie", accessibilityLabel: "Sessie starten", destination: .session,
                           height: choiceHeight)
                    separator
                    choice("Doelstelling", accessibilityLabel: "Doelstelling toevoegen", destination: .goal,
                           height: choiceHeight)
                }.frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: bottomClearance).allowsHitTesting(false)
            }
        }
        .background(FieldGuideTheme.charcoal.ignoresSafeArea())
        .fullScreenCover(item: $destination, onDismiss: {
            if startedLive { startedLive = false; isPresented = false; onLiveStarted() }
        }) { selected in
            switch selected {
            case .observation: AddObservationPicker()
            case .session: SessionForm(live: true) { startedLive = true; destination = nil }
            case .goal: GoalForm()
            }
        }
    }

    private var separator: some View {
        Rectangle().fill(FieldGuideTheme.beige.opacity(0.3)).frame(height: 0.5)
            .accessibilityHidden(true)
    }

    private func choice(_ title: String, accessibilityLabel: String, destination: AddDestination, height: CGFloat) -> some View {
        Button { self.destination = destination } label: {
            SerifText(title, size: 32, relativeTo: .title)
                .foregroundStyle(FieldGuideTheme.beige)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: height)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
    }
}

private struct AddObservationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected: Species?
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Kies een vogel") { dismiss() }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    BirdTextField("Zoek een vogel", text: $search).modifier(RoundedSearchField()).autocorrectionDisabled()
                    ForEach(SpeciesCatalogSearch.results(for: search, in: SpeciesGuideCatalog.species)) { bird in
                        Button { selected = bird } label: {
                            HStack(spacing: 16) {
                                PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    SerifText(bird.dutchName, size: 16, relativeTo: .body)
                                    Text(bird.englishDisplayName).font(FieldGuideTheme.sans(11.2, relativeTo: .caption))
                                }
                            }.frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding(20)
            }.background(FieldGuideTheme.ivory)
                .fullScreenCover(item: $selected) { bird in ObservationForm(species: bird) }
        }.foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory.ignoresSafeArea())
    }
}
