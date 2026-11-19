import SwiftUI

private enum AddDestination: String, Identifiable {
    case observation, session, goal
    var id: String { rawValue }
}

struct AddEntryView: View {
    @Binding var isPresented: Bool
    @State private var destination: AddDestination?
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    choice("Waarneming", accessibilityLabel: "Waarneming toevoegen", destination: .observation,
                           height: max(96, (geometry.size.height - 1) / 3))
                    separator
                    choice("Sessie", accessibilityLabel: "Sessie toevoegen", destination: .session,
                           height: max(96, (geometry.size.height - 1) / 3))
                    separator
                    choice("Doelstelling", accessibilityLabel: "Doelstelling toevoegen", destination: .goal,
                           height: max(96, (geometry.size.height - 1) / 3))
                }.frame(maxWidth: .infinity)
            }
        }
        .background(FieldGuideTheme.charcoal.ignoresSafeArea())
        .fullScreenCover(item: $destination) { selected in
            switch selected {
            case .observation: AddObservationPicker()
            case .session: SessionForm(live: false) { destination = nil; isPresented = false }
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
            Text(title)
                .font(.custom("Fraunces-9ptBlack", size: 32, relativeTo: .title).weight(.regular))
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
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    TextField("Zoek een vogel", text: $search).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                    ForEach(SpeciesCatalogSearch.results(for: search, in: SpeciesGuideCatalog.species)) { bird in
                        Button { selected = bird } label: {
                            HStack(spacing: 16) {
                                PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                                Text(bird.dutchName).font(.custom("Fraunces-9ptBlack", size: 16, relativeTo: .body).weight(.regular))
                            }.frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding(20)
            }.background(FieldGuideTheme.ivory)
                .navigationTitle("Kies een vogel").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Terug naar toevoegopties")
                } }
                .fullScreenCover(item: $selected) { bird in ObservationForm(species: bird) }
        }
    }
}
