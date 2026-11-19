import SwiftUI

private enum AddDestination: String, Identifiable {
    case observation, session, goal
    var id: String { rawValue }
}

struct AddEntryView: View {
    @Binding var isPresented: Bool
    @State private var destination: AddDestination?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button { isPresented = false } label: {
                    Image(systemName: "chevron.left").font(.system(size: 22, weight: .light)).frame(width: 44, height: 44)
                }.accessibilityLabel("Terug")
                Text("Toevoegen").font(FieldGuideTheme.sans(34, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                card("Waarneming toevoegen", symbol: "bird", destination: .observation)
                card("Sessie toevoegen", symbol: "clock", destination: .session)
                card("Doelstelling toevoegen", symbol: "checklist", destination: .goal)
            }.padding(20).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(FieldGuideTheme.ivory)
        .fullScreenCover(item: $destination) { selected in
            switch selected {
            case .observation: AddObservationPicker()
            case .session: SessionForm(live: false) { destination = nil; isPresented = false }
            case .goal: GoalForm()
            }
        }
    }

    private func card(_ title: String, symbol: String, destination choice: AddDestination) -> some View {
        Button { destination = choice } label: {
            HStack(spacing: 20) {
                Image(systemName: symbol).font(.system(size: 30, weight: .ultraLight)).frame(width: 40)
                Text(title).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
            }.padding(24).frame(maxWidth: .infinity, minHeight: 116)
                .background(FieldGuideTheme.beige.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(FieldGuideTheme.beige, lineWidth: 0.75) }
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
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
                    ForEach(SpeciesCatalogSearch.results(for: search, in: DiscoverFixtures.catalog)) { bird in
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
