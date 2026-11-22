import SwiftUI

@main
struct BirdingCompanionApp: App {
    @StateObject private var store: ObservationStore

    init() {
        let directory = URL.applicationSupportDirectory.appendingPathComponent("BirdingCompanion", isDirectory: true)
        _store = StateObject(wrappedValue: ObservationStore(
            persistence: JSONObservationPersistence(url: directory.appendingPathComponent("observations-v1.json"))
        ))
    }

    var body: some Scene {
        WindowGroup {
            CompanionRootView().environmentObject(store)
                .preferredColorScheme(.light)
                .font(FieldGuideTheme.sans())
                .tint(FieldGuideTheme.taupe)
                .foregroundStyle(FieldGuideTheme.charcoal)
        }
    }
}
