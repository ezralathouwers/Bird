import ActivityKit
import Foundation

@MainActor
enum AudioRecordingActivity {
    private static var current: Activity<AudioRecordingAttributes>?
    private static var heartbeat: Task<Void, Never>?
    static func start(startedAt: Date) {
        heartbeat?.cancel()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Clean up stale indicators left by a killed process before starting.
        let stale = Activity<AudioRecordingAttributes>.activities
        current = try? Activity.request(attributes: AudioRecordingAttributes(title: "Birder Audio ID"),
            content: ActivityContent(state: AudioRecordingAttributes.ContentState(startedAt: startedAt), staleDate: Date().addingTimeInterval(60)), pushType: nil)
        heartbeat = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let activity = current else { return }
                await activity.update(ActivityContent(state: .init(startedAt: startedAt), staleDate: Date().addingTimeInterval(60)))
            }
        }
        Task { for activity in stale { await activity.end(nil, dismissalPolicy: .immediate) } }
    }
    static func stop() {
        heartbeat?.cancel(); heartbeat = nil
        let activities = Activity<AudioRecordingAttributes>.activities
        current = nil
        Task { for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) } }
    }
}
