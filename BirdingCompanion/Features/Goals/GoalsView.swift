import SwiftUI
import UniformTypeIdentifiers

struct GoalsView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var showForm = false
    @State private var exporting = false
    @State private var document = ObservationExport(data: Data())
    @State private var error: String?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    PageHeading(text: "Doelstellingen")
                        .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                    RoundAction(symbol: "plus", label: "Doelstelling toevoegen") { showForm = true }
                        .disabled(store.loadError != nil)
                }
                if let message = store.loadError { Text(message).foregroundStyle(.red) }
                else if store.goals.isEmpty { Text("Maak een checklist met de vogels die je wilt zien.") }
                ForEach(store.goals.sorted { $0.createdAt > $1.createdAt }) { goal in
                    NavigationLink(value: goal) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(goal.name).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                            let count = goal.completedIDs(in: store.observations).count
                            HStack {
                                Text("\(count) van \(goal.speciesIDs.count) soorten gelogd")
                                    .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                Spacer()
                                if count == goal.speciesIDs.count { Image(systemName: "checkmark.circle").foregroundStyle(FieldGuideTheme.khaki) }
                            }
                            ProgressView(value: Double(count), total: Double(goal.speciesIDs.count)).tint(FieldGuideTheme.khaki)
                        }.padding(.vertical, 16).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
                Button("Exporteer alle gegevens (JSON)") {
                    do { document = ObservationExport(data: try store.exportArchiveData()); exporting = true }
                    catch { self.error = error.localizedDescription }
                }.frame(minHeight: 44).disabled(store.loadError != nil)
                if let error { Text(error).foregroundStyle(.red) }
            }.padding(20).padding(.bottom, 24)
        }
        .background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: BirdGoal.self) { goal in GoalDetailView(goal: goal) }
        .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
        .fullScreenCover(isPresented: $showForm) { GoalForm() }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
            defaultFilename: "birding-alle-gegevens") { result in
                if case .failure(let failure) = result { error = failure.localizedDescription }
            }
    }
}

private struct GoalDetailView: View {
    let goal: BirdGoal
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    private var birds: [Species] {
        goal.speciesIDs.map { id in
            DiscoverFixtures.catalog.first { $0.id == id } ?? BirdNETSpeciesLookup.species(id: id) ?? Species(id: id, taxonomyVersion: "unknown",
                dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Terug naar doelstellingen")
                Text(goal.name).font(FieldGuideTheme.sans(28, relativeTo: .title)).accessibilityAddTraits(.isHeader)
                if let error = store.loadError { Text(error).foregroundStyle(.red) }
                else {
                    Text("\(goal.completedIDs(in: store.observations).count) van \(goal.speciesIDs.count) soorten gelogd")
                        .font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                    ForEach(birds) { bird in
                        NavigationLink(value: bird) {
                            HStack(spacing: 16) {
                                PrimaryBirdArtwork(species: bird).frame(width: 72.8, height: 72.8)
                                VStack(alignment: .leading, spacing: 6) {
                                    SerifText(bird.dutchName, size: 16, relativeTo: .body)
                                    Text(bird.englishDisplayName).font(FieldGuideTheme.sans(11.2, relativeTo: .caption))
                                    if bird.scientificName.isEmpty { Text(bird.id).font(FieldGuideTheme.sans(11, relativeTo: .caption)) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: store.logStatus(for: bird.id) == .logged ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .light)).foregroundStyle(FieldGuideTheme.khaki)
                                    .accessibilityLabel(store.logStatus(for: bird.id) == .logged ? "Gelogd" : "Nog niet gelogd")
                            }.padding(.vertical, 12).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }.padding(20).padding(.bottom, 24)
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
    }
}

struct GoalForm: View {
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var search = ""
    @State private var selected = Set<String>()
    @State private var error: String?
    private var birds: [Species] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return SpeciesGuideCatalog.species.filter { bird in
            term.isEmpty || ([bird.dutchName, bird.englishName, bird.scientificName] + bird.aliases).contains {
                $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }.sorted { $0.dutchName.localizedStandardCompare($1.dutchName) == .orderedAscending }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    TextField("Naam van je doelstelling", text: $name)
                        .font(FieldGuideTheme.sans(22, relativeTo: .title2)).modifier(RoundedSearchField())
                    Text("\(selected.count) soorten geselecteerd").font(FieldGuideTheme.sans(16))
                    TextField("Zoek een vogel", text: $search).modifier(RoundedSearchField()).autocorrectionDisabled()
                    if birds.isEmpty { Text("Geen soorten gevonden.") }
                    ForEach(birds) { bird in
                        Button {
                            if selected.contains(bird.id) { selected.remove(bird.id) } else { selected.insert(bird.id) }
                        } label: {
                            HStack(spacing: 16) {
                                PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                                VStack(alignment: .leading, spacing: 6) {
                                    SerifText(bird.dutchName, size: 16, relativeTo: .body)
                                    Text(bird.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: selected.contains(bird.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(FieldGuideTheme.khaki)
                            }.frame(minHeight: 64).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(selected.contains(bird.id) ? [.isSelected] : [])
                        Divider()
                    }
                    Text("Reeds gelogde soorten worden meteen afgevinkt.").font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }.background(FieldGuideTheme.ivory)
                .safeAreaInset(edge: .bottom) {
                    Button("Doelstelling opslaan") {
                        let ids = SpeciesGuideCatalog.species.filter { selected.contains($0.id) }.map(\.id)
                        do {
                            try store.addGoal(BirdGoal(name: name.trimmingCharacters(in: .whitespacesAndNewlines), speciesIDs: ids))
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(FieldGuideTheme.ivory)
                        .background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius, style: .continuous))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty || store.loadError != nil)
                        .padding(20).background(FieldGuideTheme.ivory)
                }
                .navigationTitle("Doelstelling toevoegen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Terug zonder opslaan")
                } }
        }
    }
}
