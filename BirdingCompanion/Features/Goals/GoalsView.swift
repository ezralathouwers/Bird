import SwiftUI
import UIKit

struct GoalsView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var showForm = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    PageHeading(text: "Doelstellingen")
                        .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                    RoundAction(symbol: "plus", label: "Doelstelling toevoegen") { showForm = true }
                        .disabled(store.loadError != nil)
                }
                if let message = store.loadError { Text(message).foregroundStyle(.red) }
                else if store.goals.isEmpty { Text("Maak een checklist met de vogels die je wilt zien.") }
                ForEach(store.goals.sorted { $0.createdAt > $1.createdAt }) { goal in
                    NavigationLink(value: goal) { GoalCard(goal: goal) }.buttonStyle(.plain)
                }
            }.padding(20).padding(.bottom, 74)
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
            GoalProgress(goal: goal)
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
                            .opacity(0.65).blendMode(.multiply)
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
            ScrollView {
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
                }.padding(20).padding(.bottom, 24)
            }
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $editing) { GoalForm(goal: current) }
    }
}

struct GoalForm: View {
    private let original: BirdGoal?
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var search = ""
    @State private var selection: GoalSpeciesSelection
    @State private var error: String?
    init(goal: BirdGoal? = nil) {
        original = goal
        _name = State(initialValue: goal?.name ?? "")
        _selection = State(initialValue: GoalSpeciesSelection(ids: Set(goal?.speciesIDs ?? []), favoriteID: goal?.favoriteSpeciesID))
    }
    private var birds: [Species] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let catalog = SpeciesGuideCatalog.species
        let known = Set(catalog.map(\.id))
        let unknown = selection.ids.subtracting(known).map {
            Species(id: $0, taxonomyVersion: "unknown", dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
        }
        return (catalog + unknown).filter { bird in
            term.isEmpty || ([bird.dutchName, bird.englishName, bird.scientificName] + bird.aliases).contains {
                $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }.sorted { $0.dutchName.localizedStandardCompare($1.dutchName) == .orderedAscending }
    }
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: original == nil ? "Doelstelling toevoegen" : "Doelstelling bewerken") { dismiss() }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    TextField("Naam van je doelstelling", text: $name)
                        .font(FieldGuideTheme.sans(22, relativeTo: .title2)).modifier(RoundedSearchField())
                    Text("\(selection.ids.count) soorten geselecteerd").font(FieldGuideTheme.sans(16))
                    TextField("Zoek een vogel", text: $search).modifier(RoundedSearchField()).autocorrectionDisabled()
                    if birds.isEmpty { Text("Geen soorten gevonden.") }
                    ForEach(birds) { bird in
                        Button { selection.toggle(bird.id) } label: {
                            HStack(spacing: 16) {
                                PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
                                VStack(alignment: .leading, spacing: 6) {
                                    SerifText(bird.dutchName, size: 16, relativeTo: .body)
                                    Text(bird.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if selection.favoriteID == bird.id {
                                    FavoriteStar().fill(FieldGuideTheme.khaki).frame(width: 16, height: 16)
                                        .accessibilityLabel("Favoriet")
                                }
                                Image(systemName: selection.ids.contains(bird.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(FieldGuideTheme.khaki)
                            }.frame(minHeight: 64).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .highPriorityGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in selection.chooseFavorite(bird.id) })
                            .accessibilityAddTraits(selection.ids.contains(bird.id) ? [.isSelected] : [])
                            .accessibilityAction(named: "Maak favoriet") { selection.chooseFavorite(bird.id) }
                            .accessibilityHint("Houd ingedrukt om als favoriet te kiezen")
                        Divider()
                    }
                    Text("Reeds gelogde soorten worden meteen afgevinkt.").font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                Button(original == nil ? "Doelstelling opslaan" : "Wijzigingen opslaan", action: save)
                    .frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(FieldGuideTheme.ivory)
                    .background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selection.ids.isEmpty || store.loadError != nil)
                    .padding(20).background(FieldGuideTheme.ivory)
            }
        }.foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory.ignoresSafeArea())
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
