import Foundation
import ActivityKit
import seenn_flutter

// MARK: - Live Activity Bridge Implementation
//
// This file implements the SeennLiveActivityBridge protocol.
// It's compiled in your app's module, so it uses YOUR SeennJobAttributes.
// This avoids the "ActivityInput error 0" module isolation issue.

@available(iOS 16.2, *)
class SeennLiveActivityBridgeImpl: SeennLiveActivityBridge {

    static let shared = SeennLiveActivityBridgeImpl()

    private var activities: [String: Activity<SeennJobAttributes>] = [:]
    private var tokenCallbacks: [String: (String) -> Void] = [:]

    private init() {}

    // MARK: - SeennLiveActivityBridge Protocol

    func areActivitiesEnabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func startActivity(
        jobId: String,
        title: String,
        jobType: String,
        initialProgress: Int,
        initialMessage: String?,
        onPushToken: @escaping (String) -> Void
    ) throws -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw SeennLiveActivityError.activitiesNotEnabled
        }

        let attributes = SeennJobAttributes(
            jobId: jobId,
            title: title,
            jobType: jobType
        )

        let initialState = SeennJobAttributes.ContentState(
            progress: initialProgress,
            status: "running",
            message: initialMessage ?? "Starting...",
            stageName: nil,
            stageIndex: nil,
            stageTotal: nil,
            eta: nil,
            resultUrl: nil,
            errorMessage: nil
        )

        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil),
            pushType: .token
        )

        activities[jobId] = activity
        tokenCallbacks[jobId] = onPushToken

        // Listen for push token updates
        Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                await MainActor.run {
                    self.tokenCallbacks[jobId]?(token)
                }
            }
        }

        return activity.id
    }

    func updateActivity(
        jobId: String,
        progress: Int,
        status: String,
        message: String?,
        stageName: String?,
        stageIndex: Int?,
        stageTotal: Int?,
        eta: Int?,
        resultUrl: String?
    ) async throws {
        guard let activity = activities[jobId] else {
            throw SeennLiveActivityError.activityNotFound
        }

        let updatedState = SeennJobAttributes.ContentState(
            progress: progress,
            status: status,
            message: message,
            stageName: stageName,
            stageIndex: stageIndex,
            stageTotal: stageTotal,
            eta: eta,
            resultUrl: resultUrl,
            errorMessage: nil
        )

        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )
    }

    func endActivity(
        jobId: String,
        finalProgress: Int,
        finalStatus: String,
        message: String?,
        resultUrl: String?,
        errorMessage: String?,
        dismissAfter: TimeInterval
    ) async throws {
        guard let activity = activities[jobId] else {
            throw SeennLiveActivityError.activityNotFound
        }

        let finalState = SeennJobAttributes.ContentState(
            progress: finalProgress,
            status: finalStatus,
            message: message,
            stageName: nil,
            stageIndex: nil,
            stageTotal: nil,
            eta: nil,
            resultUrl: resultUrl,
            errorMessage: errorMessage
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(dismissAfter))
        )

        activities.removeValue(forKey: jobId)
        tokenCallbacks.removeValue(forKey: jobId)
    }

    func isActivityActive(jobId: String) -> Bool {
        guard let activity = activities[jobId] else { return false }
        return activity.activityState == .active
    }

    func getActiveActivityIds() -> [String] {
        return Array(activities.keys)
    }

    func cancelActivity(jobId: String) async {
        guard let activity = activities[jobId] else { return }

        await activity.end(nil, dismissalPolicy: .immediate)

        activities.removeValue(forKey: jobId)
        tokenCallbacks.removeValue(forKey: jobId)
    }

    func cancelAllActivities() async {
        for (jobId, activity) in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            activities.removeValue(forKey: jobId)
            tokenCallbacks.removeValue(forKey: jobId)
        }
    }
}
