//
//  SeennLiveActivityWidgetLiveActivity.swift
//  SeennLiveActivityWidget
//
//  Created by Melih DRS on 21.01.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

// SeennJobAttributes is defined in SeennJobAttributes.swift (shared file)

// MARK: - Live Activity Widget

struct SeennLiveActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SeennJobAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: iconForJobType(context.attributes.jobType))
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let stageName = context.state.stageName {
                        Text(stageName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status indicator
                StatusBadge(status: context.state.status)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(context.state.progress), total: 100)
                    .tint(colorForStatus(context.state.status))

                HStack {
                    Text("\(context.state.progress)%")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let eta = context.state.eta {
                        Text(formatETA(eta))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Message
            if let message = context.state.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Error message
            if let errorMessage = context.state.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color(.systemBackground))
    }
}

// MARK: - Dynamic Island Views

struct CompactLeadingView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        Image(systemName: iconForJobType(context.attributes.jobType))
            .foregroundColor(.blue)
    }
}

struct CompactTrailingView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        Text("\(context.state.progress)%")
            .font(.caption2)
            .fontWeight(.semibold)
    }
}

struct MinimalView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        Image(systemName: iconForJobType(context.attributes.jobType))
            .foregroundColor(.blue)
    }
}

struct ExpandedLeadingView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: iconForJobType(context.attributes.jobType))
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        VStack(alignment: .trailing) {
            Text("\(context.state.progress)%")
                .font(.title2)
                .fontWeight(.bold)

            StatusBadge(status: context.state.status)
        }
    }
}

struct ExpandedCenterView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        VStack(spacing: 4) {
            Text(context.attributes.title)
                .font(.headline)
                .lineLimit(1)

            if let stageName = context.state.stageName,
               let stageIndex = context.state.stageIndex,
               let stageTotal = context.state.stageTotal {
                Text("Step \(stageIndex + 1)/\(stageTotal): \(stageName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<SeennJobAttributes>

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(context.state.progress), total: 100)
                .tint(colorForStatus(context.state.status))

            HStack {
                if let message = context.state.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let eta = context.state.eta {
                    Text(formatETA(eta))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(statusLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }

    private var statusLabel: String {
        switch status {
        case "running": return "Running"
        case "completed": return "Done"
        case "failed": return "Failed"
        case "queued": return "Queued"
        case "pending": return "Pending"
        default: return status.capitalized
        }
    }

    private var statusColor: Color {
        switch status {
        case "running": return .blue
        case "completed": return .green
        case "failed": return .red
        case "queued": return .orange
        case "pending": return .gray
        default: return .gray
        }
    }
}

// MARK: - Helper Functions

func iconForJobType(_ jobType: String) -> String {
    switch jobType.lowercased() {
    case "video", "video_generation":
        return "video.fill"
    case "image", "image_generation":
        return "photo.fill"
    case "audio", "speech", "tts":
        return "waveform"
    case "transcription", "stt":
        return "text.bubble.fill"
    case "document", "pdf":
        return "doc.fill"
    case "analysis", "ai":
        return "brain"
    default:
        return "gearshape.fill"
    }
}

func colorForStatus(_ status: String) -> Color {
    switch status {
    case "running": return .blue
    case "completed": return .green
    case "failed": return .red
    case "queued": return .orange
    case "pending": return .gray
    default: return .blue
    }
}

func formatETA(_ seconds: Int) -> String {
    if seconds < 60 {
        return "\(seconds)s left"
    } else if seconds < 3600 {
        let minutes = seconds / 60
        return "\(minutes)m left"
    } else {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m left"
    }
}

// MARK: - Preview

extension SeennJobAttributes {
    fileprivate static var preview: SeennJobAttributes {
        SeennJobAttributes(
            jobId: "job_123",
            title: "Generating AI Video",
            jobType: "video"
        )
    }
}

extension SeennJobAttributes.ContentState {
    fileprivate static var running: SeennJobAttributes.ContentState {
        SeennJobAttributes.ContentState(
            progress: 45,
            status: "running",
            message: "Rendering frames...",
            stageName: "Rendering",
            stageIndex: 2,
            stageTotal: 4,
            eta: 120
        )
    }

    fileprivate static var completed: SeennJobAttributes.ContentState {
        SeennJobAttributes.ContentState(
            progress: 100,
            status: "completed",
            message: "Video ready!",
            resultUrl: "https://example.com/video.mp4"
        )
    }
}

#Preview("Notification", as: .content, using: SeennJobAttributes.preview) {
    SeennLiveActivityWidgetLiveActivity()
} contentStates: {
    SeennJobAttributes.ContentState.running
    SeennJobAttributes.ContentState.completed
}
