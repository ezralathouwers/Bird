import SwiftUI
@preconcurrency import UIKit

// One requested correction of history, not an ongoing timezone conversion.
enum SessionTimeAdjustment {
    static let identifier = "existing-sessions-plus-two-hours-2026-11-25"
    static func apply(to archive: BirdingArchive) -> BirdingArchive {
        guard !(archive.appliedDataFixes ?? []).contains(identifier) else { return archive }
        var result = archive
        let targets = Set(archive.sessions.filter { $0.endedAt != nil && $0.importMetadata?[identifier] == nil }.map(\.id))
        let formatter = ISO8601DateFormatter()
        for index in result.sessions.indices where targets.contains(result.sessions[index].id) {
            var session = result.sessions[index]
            session.importMetadata = session.importMetadata ?? [:]
            session.importMetadata?[identifier] = "7200"
            session.importMetadata?[identifier + ".originalStart"] = formatter.string(from: session.startedAt)
            session.importMetadata?[identifier + ".originalEnd"] = session.endedAt.map { formatter.string(from: $0) }
            session.startedAt = session.startedAt.addingTimeInterval(7200)
            session.endedAt = session.endedAt?.addingTimeInterval(7200)
            result.sessions[index] = session
        }
        for index in result.observations.indices {
            guard let sessionID = result.observations[index].sessionID, targets.contains(sessionID) else { continue }
            result.observations[index].observedAt = result.observations[index].observedAt.addingTimeInterval(7200)
        }
        result.appliedDataFixes = Array(Set((archive.appliedDataFixes ?? []) + [identifier])).sorted()
        return result
    }
}

enum SessionCatalogSearch {
    static func matches(_ query: String, session: BirdSession, logs: [Observation], catalog: [Species]) -> Bool {
        let terms = normalized(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return true }
        let ids = Set(logs.map(\.speciesID))
        let names = catalog.filter { ids.contains($0.id) }.flatMap { [$0.dutchName, $0.englishName, $0.scientificName] + $0.aliases }
        let fields = [session.locationName, session.countryCode.map { ObservationCountry.name(for: $0) } ?? "", session.historyDate(session.startedAt, time: .omitted)] + names
        let text = normalized(fields.joined(separator: " "))
        return terms.allSatisfy { text.contains($0) }
    }
    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
    }
}

enum SessionHabitatProjection {
    static func sceneID(logs: [Observation], primaryScene: (String) -> String?) -> String? {
        // One vote per species, so repeated common birds do not dominate.
        var counts: [String: Int] = [:]
        for id in Set(logs.filter { $0.status == .confirmed && !$0.isCaptive }.map(\.speciesID)) {
            if let scene = primaryScene(id) { counts[scene, default: 0] += 1 }
        }
        return counts.keys.sorted { counts[$0] == counts[$1] ? $0 < $1 : counts[$0, default: 0] > counts[$1, default: 0] }.first
    }
    static func suggested(logs: [Observation]) -> HabitatScene? {
        guard let id = sceneID(logs: logs, primaryScene: { id in
            SpeciesGuideCatalog.species(id: id).flatMap { HabitatSceneCatalog.primaryScene(for: $0)?.id }
        }) else { return nil }
        return HabitatSceneCatalog.scenes.first { $0.id == id }
    }
    static func scene(session: BirdSession, logs: [Observation]) -> HabitatScene? {
        if let id = session.habitatSceneID { return HabitatSceneCatalog.scenes.first { $0.id == id } }
        return suggested(logs: logs)
    }
}

struct SessionCountryTitle: View {
    let session: BirdSession
    var size: CGFloat = 20
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let code = ObservationCountry.normalized(session.countryCode), code != "BE" {
                CountryFlagBadge(code: code, diameter: 24).accessibilityLabel(ObservationCountry.name(for: code))
            }
            Text(session.locationName).font(FieldGuideTheme.sans(size, relativeTo: .title3))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SessionHabitatArtwork: View {
    let scene: HabitatScene
    @State private var image: UIImage?
    var body: some View {
        // Keep a concrete view mounted while image is nil, so the loading task
        // also starts on the first appearance of a session row.
        Color.clear.overlay {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
        }.task(id: scene.id) {
            image = nil
            guard let source = await HabitatArtworkCache.image(for: scene), !Task.isCancelled else { return }
            image = source
            let thumbnail = await source.byPreparingThumbnail(ofSize: CGSize(width: 400, height: 240))
            guard !Task.isCancelled else { return }
            image = thumbnail ?? source
        }.accessibilityHidden(true)
    }
}
