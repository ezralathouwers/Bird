import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BirderRecordingWidgets: WidgetBundle {
    var body: some Widget { BirderAudioActivityWidget() }
}
struct BirderAudioActivityWidget: Widget {
    private let olive = Color(red: 133.0 / 255, green: 131.0 / 255, blue: 107.0 / 255)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudioRecordingAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "waveform").font(.title2)
                VStack(alignment: .leading) {
                    Text("Birder · Audio ID").font(.headline)
                    Text(context.isStale ? "Open Birder om de opname te controleren" : "Aan het luisteren naar vogels").font(.caption)
                }
                Spacer()
                Text(context.state.startedAt, style: .timer).monospacedDigit()
            }.padding(18).foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.92))
                .activityBackgroundTint(olive)
                .widgetURL(URL(string: "birder://audio"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: context.isStale ? "waveform.slash" : "waveform").foregroundStyle(olive) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.startedAt, style: .timer).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) { Text(context.isStale ? "Open Birder om de opname te controleren" : "Birder · Audio ID — aan het luisteren").font(.caption) }
            } compactLeading: {
                Image(systemName: context.isStale ? "waveform.slash" : "waveform").foregroundStyle(olive)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer).monospacedDigit().frame(width: 48)
            } minimal: {
                Image(systemName: context.isStale ? "waveform.slash" : "waveform").foregroundStyle(olive)
            }.widgetURL(URL(string: "birder://audio"))
        }
    }
}
