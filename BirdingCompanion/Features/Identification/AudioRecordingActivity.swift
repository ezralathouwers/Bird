import ActivityKit
import Foundation

// Keep SDK handles local to nonisolated operations. Only IDs and timestamps
// cross the main-actor/task boundary; Activity is not Sendable on every SDK.
private enum RecordingActivityClient {
    nonisolated static func activeIDs() -> [String] {
        Activity<AudioRecordingAttributes>.activities.map(\.id)
    }
    nonisolated static func request(startedAt: Date) -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        return try? Activity<AudioRecordingAttributes>.request(
            attributes: AudioRecordingAttributes(title: "Birder Audio ID"),
            content: ActivityContent(state: .init(startedAt: startedAt), staleDate: Date().addingTimeInterval(60)),
            pushType: nil).id
    }
    nonisolated static func refresh(id: String, startedAt: Date) async {
        guard let activity = Activity<AudioRecordingAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(ActivityContent(state: .init(startedAt: startedAt), staleDate: Date().addingTimeInterval(60)))
    }
    nonisolated static func end(ids: [String]) async {
        for id in ids {
            guard let activity = Activity<AudioRecordingAttributes>.activities.first(where: { $0.id == id }) else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

@MainActor
enum AudioRecordingActivity {
    private static var currentID: String?
    private static var heartbeat: Task<Void, Never>?
    static func start(startedAt: Date) {
        heartbeat?.cancel()
        let staleIDs = RecordingActivityClient.activeIDs()
        currentID = RecordingActivityClient.request(startedAt: startedAt)
        if let id = currentID {
            heartbeat = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(20))
                    guard !Task.isCancelled, currentID == id else { return }
                    await RecordingActivityClient.refresh(id: id, startedAt: startedAt)
                }
            }
        }
        Task { await RecordingActivityClient.end(ids: staleIDs) }
    }
    static func stop() {
        heartbeat?.cancel(); heartbeat = nil
        let ids = RecordingActivityClient.activeIDs()
        currentID = nil
        Task { await RecordingActivityClient.end(ids: ids) }
    }
}
