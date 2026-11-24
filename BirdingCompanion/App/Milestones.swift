import SwiftUI

struct BirdingMilestone: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

// Derived from confirmed, non-captive logs; no independent totals to drift.
enum MilestoneProjection {
    static func earned(observations: [Observation], goals: [BirdGoal], catalog: [Species]) -> [BirdingMilestone] {
        let ids = LifelistRules().speciesIDs(in: observations)
        var result = [BirdingMilestone]()
        for count in [1, 10, 25, 50, 100, 200, 300, 500, 750, 1000, 2000, 5000, 10000] where ids.count >= count {
            result.append(.init(id: "lifelist-\(count)", title: count == 1 ? "Je eerste vogel" : "\(count) vogelsoorten",
                                subtitle: count == 1 ? "Het begin van jouw vogelverhaal." : "Elke soort een eigen ontdekking."))
        }
        if catalog.contains(where: { ids.contains($0.id) && ["Strigidae", "Tytonidae"].contains($0.family?.id ?? "") }) {
            result.append(.init(id: "first-owl", title: "Je eerste uil", subtitle: "Een bijzondere ontmoeting voor je veldboek."))
        }
        let families = Dictionary(grouping: catalog.filter { $0.family != nil }, by: { $0.family! })
        for (family, species) in families.sorted(by: { $0.key.id < $1.key.id }) where species.count > 1 && species.allSatisfy({ ids.contains($0.id) }) {
            result.append(.init(id: "family-\(family.id)", title: family.dutchName, subtitle: "Alle soorten van deze familie ontdekt."))
        }
        for goal in goals.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where !goal.speciesIDs.isEmpty && Set(goal.speciesIDs).isSubset(of: ids) {
            result.append(.init(id: "goal-\(goal.id)", title: "Doelstelling behaald", subtitle: goal.name))
        }
        return result
    }
}

@MainActor final class MilestoneController: ObservableObject {
    @Published private(set) var current: BirdingMilestone?
    private var pending: [BirdingMilestone] = []
    private var previousIDs: Set<UUID>?
    private var previousReplacementID: UUID?
    private var seen: Set<String>
    private let defaults: UserDefaults
    private let key = "acknowledgedMilestones.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        seen = Set(defaults.stringArray(forKey: "acknowledgedMilestones.v1") ?? [])
    }
    func update(observations: [Observation], goals: [BirdGoal], catalog: [Species], historyReplacementID: UUID? = nil) {
        let ids = Set(observations.map(\.id))
        let earned = MilestoneProjection.earned(observations: observations, goals: goals, catalog: catalog)
        defer {
            previousIDs = ids
            previousReplacementID = historyReplacementID
            seen.formUnion(earned.map(\.id))
            defaults.set(seen.sorted(), forKey: key)
        }
        // Existing history/imports/restores/edits never replay a stack of old awards.
        guard let previousIDs else { return }
        if previousReplacementID != historyReplacementID {
            pending = []; current = nil
            return
        }
        let added = observations.filter { !previousIDs.contains($0.id) }
        guard !added.isEmpty, added.allSatisfy({ $0.source != "birda-csv" }),
              added.contains(where: { $0.status == .confirmed && !$0.isCaptive }) else { return }
        pending.append(contentsOf: earned.filter { !seen.contains($0.id) })
        if current == nil { advance() }
    }
    func advance() { current = pending.isEmpty ? nil : pending.removeFirst() }
}

struct MilestoneCelebration: View {
    let milestone: BirdingMilestone
    let dismiss: () -> Void
    var body: some View {
        Button(action: dismiss) {
            VStack(spacing: 20) {
                LiferStar().fill(FieldGuideTheme.ivory).frame(width: 52, height: 52).padding(.bottom, 12)
                Text(milestone.title).font(FieldGuideTheme.sans(38, relativeTo: .largeTitle))
                Text(milestone.subtitle).font(FieldGuideTheme.sans(18, relativeTo: .body))
            }.multilineTextAlignment(.center).padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(FieldGuideTheme.ivory).background(Color("LaunchOlive"))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).ignoresSafeArea()
            .accessibilityLabel("\(milestone.title). \(milestone.subtitle)")
            .accessibilityHint("Tik om verder te gaan")
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, dismiss)
    }
}
