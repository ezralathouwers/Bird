import ActivityKit
import Foundation

struct AudioRecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var startedAt: Date }
    let title: String
}
