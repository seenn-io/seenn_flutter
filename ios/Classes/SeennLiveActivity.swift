import Foundation

// MARK: - Live Activity Bridge Protocol
//
// The SDK does NOT define ActivityAttributes or call ActivityKit directly.
// This avoids the "ActivityInput error 0" caused by module isolation.
//
// Your app must implement SeennLiveActivityBridge and register it during app init.
// See: https://docs.seenn.io/client/flutter#live-activity-setup

@available(iOS 16.2, *)
public protocol SeennLiveActivityBridge: AnyObject {
    /// Check if Live Activities are enabled on this device
    func areActivitiesEnabled() -> Bool

    /// Start a new Live Activity
    /// - Returns: The activity ID
    func startActivity(
        jobId: String,
        title: String,
        jobType: String,
        initialProgress: Int,
        initialMessage: String?,
        onPushToken: @escaping (String) -> Void
    ) throws -> String

    /// Update an existing Live Activity
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
    ) async throws

    /// End a Live Activity
    func endActivity(
        jobId: String,
        finalProgress: Int,
        finalStatus: String,
        message: String?,
        resultUrl: String?,
        errorMessage: String?,
        dismissAfter: TimeInterval,
        ctaButtonText: String?,
        ctaDeepLink: String?,
        ctaButtonStyle: String?,
        ctaBackgroundColor: String?,
        ctaTextColor: String?,
        ctaCornerRadius: Int?
    ) async throws

    /// Check if an activity is active
    func isActivityActive(jobId: String) -> Bool

    /// Get all active activity IDs
    func getActiveActivityIds() -> [String]

    /// Cancel an activity immediately
    func cancelActivity(jobId: String) async

    /// Cancel all activities
    func cancelAllActivities() async
}

// MARK: - Bridge Registry

@available(iOS 16.2, *)
public class SeennLiveActivityRegistry {
    public static let shared = SeennLiveActivityRegistry()

    private var bridge: SeennLiveActivityBridge?

    private init() {}

    /// Register your app's Live Activity bridge implementation
    /// Call this in your AppDelegate or @main App init
    public func register(_ bridge: SeennLiveActivityBridge) {
        self.bridge = bridge
    }

    /// Get the registered bridge (throws if not registered)
    public func getBridge() throws -> SeennLiveActivityBridge {
        guard let bridge = bridge else {
            throw SeennLiveActivityError.bridgeNotRegistered
        }
        return bridge
    }

    /// Check if a bridge is registered
    public var isRegistered: Bool {
        return bridge != nil
    }
}

// MARK: - Errors

public enum SeennLiveActivityError: Error, LocalizedError {
    case bridgeNotRegistered
    case activitiesNotEnabled
    case activityNotFound
    case invalidState

    public var errorDescription: String? {
        switch self {
        case .bridgeNotRegistered:
            return "Live Activity bridge not registered. Call SeennLiveActivityRegistry.shared.register() in your AppDelegate. See: https://docs.seenn.io/client/flutter#live-activity-setup"
        case .activitiesNotEnabled:
            return "Live Activities are not enabled on this device"
        case .activityNotFound:
            return "Live Activity not found for the given job ID"
        case .invalidState:
            return "Invalid activity state"
        }
    }
}
