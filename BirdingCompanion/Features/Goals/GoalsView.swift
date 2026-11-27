import SwiftUI
import UIKit

struct GoalsView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var showForm = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                PageHeading(text: "Doelstellingen")
                .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                RoundAction(symbol: "plus", label: "Doelstelling toevoegen") { showForm = true }
                .disabled(store.loadError != nil)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 18)
            .fixedSize(horizontal: false, vertical: true)
            CatalogResultsScroll(resetKey: "goals") {
                LazyVStack(alignment: .leading, spacing: 18) {

                    if let message = store.loadError { Text(message).foregroundStyle(.red) }
                    else if store.goals.isEmpty { Text("Maak een checklist met de vogels die je wilt zien.") }
                    ForEach(store.goals.sorted { $0.createdAt > $1.createdAt }) { goal in
                        NavigationLink(value: goal) { GoalCard(goal: goal) }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 104)
            }
        }
        .background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: BirdGoal.self) { goal in GoalDetailView(goal: goal) }
        .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
        .fullScreenCover(isPresented: $showForm) { GoalForm() }
    }
}


private struct GoalProgress: View {
    let goal: BirdGoal
    @EnvironmentObject private var store: ObservationStore
    var body: some View {
        ProgressView(value: Double(goal.completedIDs(in: store.observations).count),
                     total: Double(goal.speciesIDs.count)).tint(FieldGuideTheme.khaki)
    }
}

private struct GoalCard: View {
    let goal: BirdGoal
    @EnvironmentObject private var store: ObservationStore
    private var favorite: Species? { goal.favoriteSpeciesID.flatMap { SpeciesGuideCatalog.species(id: $0) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(goal.name).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                .padding(.trailing, favorite == nil ? 0 : 72)
            let count = goal.completedIDs(in: store.observations).count
            Text("\(count) van \(goal.speciesIDs.count) soorten gelogd")
                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
            GeometryReader { bounds in GoalProgress(goal: goal).frame(width: bounds.size.width / 2) }.frame(height: 4)
        }
        .padding(.horizontal, 16).padding(.vertical, 28).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .trailing) {
                FieldGuideTheme.searchControlBackground
                if let favorite, UIImage(named: SpeciesMediaRole.dynamic.assetName(for: favorite)) != nil {
                    GeometryReader { bounds in
                        Image(SpeciesMediaRole.dynamic.assetName(for: favorite)).resizable().scaledToFill()
                            .frame(width: bounds.size.width * 0.48, height: bounds.size.height, alignment: .trailing)
                            .clipped()
                            .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing))
                            .blendMode(.multiply)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }.accessibilityHidden(true)
                } else if favorite != nil {
                    Image(systemName: "bird").font(.system(size: 56, weight: .ultraLight))
                        .foregroundStyle(FieldGuideTheme.taupe.opacity(0.4)).padding(.trailing, 16)
                        .accessibilityHidden(true)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(favorite.map { "Favoriet: \($0.dutchName)" } ?? "")
    }
}

private struct GoalDetailView: View {
    let goal: BirdGoal
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    private var current: BirdGoal { store.goals.first { $0.id == goal.id } ?? goal }
    private var birds: [Species] {
        current.speciesIDs.map { id in
            SpeciesGuideCatalog.species(id: id) ?? Species(id: id, taxonomyVersion: "unknown",
                dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            DetailPageHeader(title: "Doelstelling", editLabel: "Doelstelling bewerken", editDisabled: store.loadError != nil,
                             back: { dismiss() }, edit: { editing = true })
            CatalogResultsScroll(resetKey: "goalsview-page") {
                VStack(alignment: .leading, spacing: 0) {
                    Text(current.name).font(FieldGuideTheme.sans(28, relativeTo: .title))
                        .accessibilityAddTraits(.isHeader).padding(.bottom, 20)
                    if let error = store.loadError { Text(error).foregroundStyle(.red) }
                    else {
                        Text("\(current.completedIDs(in: store.observations).count) van \(current.speciesIDs.count) soorten gelogd")
                            .font(FieldGuideTheme.sans(14, relativeTo: .subheadline)).padding(.bottom, 12)
                        GoalProgress(goal: current).padding(.bottom, 30)
                        LazyVStack(spacing: 0) {
                            ForEach(birds) { bird in
                                NavigationLink(value: bird) {
                                    HStack(spacing: 16) {
                                        PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                                        VStack(alignment: .leading, spacing: 6) {
                                            SerifText(bird.dutchName, size: 16, relativeTo: .body)
                                            Text(bird.englishDisplayName).font(FieldGuideTheme.sans(11.2, relativeTo: .caption))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        if current.favoriteSpeciesID == bird.id { FavoriteStar().fill(FieldGuideTheme.khaki).frame(width: 16, height: 16) }
                                        Image(systemName: store.logStatus(for: bird.id) == .logged ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22, weight: .light)).foregroundStyle(FieldGuideTheme.khaki)
                                            .accessibilityLabel(store.logStatus(for: bird.id) == .logged ? "Gelogd" : "Nog niet gelogd")
                                    }.padding(.vertical, 6).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                }.padding(20).padding(.bottom, 89)
            }
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $editing) { GoalForm(goal: current) }
            .onChange(of: store.goals.contains { $0.id == goal.id }) { _, exists in if !exists { dismiss() } }
    }
}

struct GoalForm: View {
    private let original: BirdGoal?
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var showSearch = false
    @State private var selection: GoalSpeciesSelection
    @State private var error: String?
    @State private var confirmDelete = false
    init(goal: BirdGoal? = nil) {
        original = goal
        _name = State(initialValue: goal?.name ?? "")
        _selection = State(initialValue: GoalSpeciesSelection(ids: Set(goal?.speciesIDs ?? []), favoriteID: goal?.favoriteSpeciesID))
    }
    private var birds: [Species] {
        selection.ids.map { id in
            SpeciesGuideCatalog.species(id: id) ?? Species(id: id, taxonomyVersion: "unknown", dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
        }.sorted { $0.dutchName.localizedStandardCompare($1.dutchName) == .orderedAscending }
    }
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: original == nil ? "Doelstelling toevoegen" : "Doelstelling bewerken") { dismiss() }
            CatalogResultsScroll(resetKey: "goalsview-page") {
                LazyVStack(alignment: .leading, spacing: 20) {
                    BirdTextField("Naam van je doelstelling", text: $name)
                        .font(FieldGuideTheme.sans(22, relativeTo: .title2)).modifier(RoundedSearchField())
                    Text("\(selection.ids.count) soorten geselecteerd").font(FieldGuideTheme.sans(16))
                    Button { showSearch = true } label: {
                        HStack { FineSearchMark().stroke(style: FieldGuideTheme.navigationStroke).frame(width: 18, height: 18); Text("Zoek een vogel"); Spacer() }
                            .foregroundStyle(FieldGuideTheme.taupe).modifier(RoundedSearchField())
                    }.buttonStyle(.plain)

                    ForEach(birds) { bird in
                        GoalSelectionRow(bird: bird, selection: $selection)
                        Divider()
                    }
                    Text("Reeds gelogde soorten worden meteen afgevinkt.").font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button(original == nil ? "Doelstelling opslaan" : "Wijzigingen opslaan", action: save)
                        .frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(FieldGuideTheme.ivory)
                        .background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selection.ids.isEmpty || store.loadError != nil)
                    if original != nil {
                        Button("Doelstelling verwijderen", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity, minHeight: 44).disabled(store.loadError != nil)
                    }
                }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, original == nil ? 20 : 5).background(FieldGuideTheme.ivory)
            }
        }.foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory.ignoresSafeArea())
            .fullScreenCover(isPresented: $showSearch) { GoalSpeciesPicker(selection: $selection) }
            .confirmationDialog("Doelstelling verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Verwijder doelstelling", role: .destructive) {
                    guard let original else { return }
                    do { try store.deleteGoal(id: original.id); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
                Button("Annuleren", role: .cancel) {}
            } message: { Text("Je gelogde waarnemingen blijven bewaard.") }
    }
    private func save() {
        let previous = original?.speciesIDs ?? []
        let ids = previous.filter { selection.ids.contains($0) } + selection.ids.subtracting(Set(previous)).sorted()
        var goal = original ?? BirdGoal(name: "", speciesIDs: [])
        goal.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.speciesIDs = ids
        goal.favoriteSpeciesID = selection.favoriteID
        do {
            if original != nil { try store.updateGoal(goal) } else { try store.addGoal(goal) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct GoalSelectionRow: View {
    let bird: Species
    @Binding var selection: GoalSpeciesSelection
    var body: some View {
        Button { selection.toggle(bird.id) } label: {
            HStack(spacing: 16) {
                PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    SerifText(bird.dutchName, size: 16, relativeTo: .body)
                    Text(bird.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                }.frame(maxWidth: .infinity, alignment: .leading)
                if selection.favoriteID == bird.id { FavoriteStar().fill(FieldGuideTheme.khaki).frame(width: 16, height: 16).accessibilityLabel("Favoriet") }
                Image(systemName: selection.ids.contains(bird.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(FieldGuideTheme.khaki)
            }.frame(minHeight: 64).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in selection.chooseFavorite(bird.id) })
            .accessibilityAddTraits(selection.ids.contains(bird.id) ? [.isSelected] : [])
            .accessibilityAction(named: "Maak favoriet") { selection.chooseFavorite(bird.id) }
            .accessibilityHint("Houd ingedrukt om als favoriet te kiezen")
    }
}
private struct GoalSpeciesPicker: View {
    @Binding var selection: GoalSpeciesSelection
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @FocusState private var focused: Bool
    private var birds: [Species] {
        let catalog = SpeciesGuideCatalog.species
        let known = Set(catalog.map(\.id))
        let unknown = selection.ids.subtracting(known).map {
            SpeciesGuideCatalog.species(id: $0) ?? Species(id: $0, taxonomyVersion: "unknown", dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
        }
        return SpeciesCatalogSearch.results(for: search, in: catalog + unknown)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SpeciesBackButton { dismiss() }.padding(.top, 4)
            Text("Vogels selecteren").font(FieldGuideTheme.sans(24, relativeTo: .title2))
            BirdTextField("Zoek een vogel", text: $search).modifier(RoundedSearchField()).autocorrectionDisabled().focused($focused)
            CatalogResultsScroll(resetKey: search) {
                LazyVStack(spacing: 12) {
                    ForEach(birds) { bird in GoalSelectionRow(bird: bird, selection: $selection); Divider() }
                    if birds.isEmpty { Text("Geen soorten gevonden.") }
                }.padding(.bottom, 24)
            }
        }.padding(.horizontal, 20).foregroundStyle(FieldGuideTheme.charcoal)
            .background(FieldGuideTheme.ivory.ignoresSafeArea()).task { focused = true }
    }
}

private struct FavoriteStar: Shape {
    func path(in rect: CGRect) -> Path {
        let points = (0..<10).map { index -> CGPoint in
            let angle = Double(index) * .pi / 5 - .pi / 2
            let radius: CGFloat = index.isMultiple(of: 2) ? 0.48 : 0.23
            return CGPoint(x: rect.midX + CGFloat(cos(angle)) * rect.width * radius,
                           y: rect.midY + CGFloat(sin(angle)) * rect.height * radius)
        }
        var path = Path()
        for index in points.indices {
            let previous = points[(index + 9) % 10], point = points[index], next = points[(index + 1) % 10]
            let start = CGPoint(x: point.x + (previous.x - point.x) * 0.18, y: point.y + (previous.y - point.y) * 0.18)
            let end = CGPoint(x: point.x + (next.x - point.x) * 0.18, y: point.y + (next.y - point.y) * 0.18)
            if index == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: point)
        }
        path.closeSubpath()
        return path
    }
}
