import Flutter
import UIKit
import UserNotifications

public class SeennFlutterPlugin: NSObject, FlutterPlugin {

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var pendingTokens: [[String: Any]] = []
    private var pendingDeviceTokens: [[String: Any]] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SeennFlutterPlugin()

        // Method channel for commands
        let methodChannel = FlutterMethodChannel(
            name: "io.seenn/live_activity",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Event channel for push token updates
        let eventChannel = FlutterEventChannel(
            name: "io.seenn/live_activity_events",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)

        // Setup device push token callback
        instance.setupDevicePushTokenCallback()
    }

    private func setupDevicePushTokenCallback() {
        SeennPushTokenHandler.shared.setDeviceTokenCallback { [weak self] token in
            let event: [String: Any] = [
                "type": "devicePushToken",
                "token": token
            ]
            if let sink = self?.eventSink {
                sink(event)
            } else {
                // Buffer token until Dart listener is ready
                self?.pendingDeviceTokens.append(event)
            }
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "isLiveActivitySupported":
            if #available(iOS 16.2, *) {
                result(true)
            } else {
                result(false)
            }

        case "areActivitiesEnabled":
            handleAreActivitiesEnabled(result: result)

        case "isBridgeRegistered":
            if #available(iOS 16.2, *) {
                result(SeennLiveActivityRegistry.shared.isRegistered)
            } else {
                result(false)
            }

        case "startLiveActivity":
            handleStartLiveActivity(call: call, result: result)

        case "updateLiveActivity":
            handleUpdateLiveActivity(call: call, result: result)

        case "endLiveActivity":
            handleEndLiveActivity(call: call, result: result)

        case "cancelLiveActivity":
            handleCancelLiveActivity(call: call, result: result)

        case "isActivityActive":
            handleIsActivityActive(call: call, result: result)

        case "getActiveActivityIds":
            handleGetActiveActivityIds(result: result)

        case "cancelAllActivities":
            handleCancelAllActivities(result: result)

        // Push Authorization (iOS 12+)
        case "getPushAuthorizationStatus":
            handleGetPushAuthorizationStatus(result: result)

        case "requestProvisionalPushAuthorization":
            handleRequestProvisionalPushAuthorization(result: result)

        case "requestStandardPushAuthorization":
            handleRequestStandardPushAuthorization(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Are Activities Enabled

    private func handleAreActivitiesEnabled(result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            do {
                let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                result(bridge.areActivitiesEnabled())
            } catch {
                result(FlutterError(code: "BRIDGE_NOT_REGISTERED", message: error.localizedDescription, details: nil))
            }
        } else {
            result(false)
        }
    }

    // MARK: - Start Live Activity

    private func handleStartLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String,
                  let title = args["title"] as? String,
                  let jobType = args["jobType"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }

            let initialProgress = args["initialProgress"] as? Int ?? 0
            let initialMessage = args["initialMessage"] as? String

            do {
                let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                let activityId = try bridge.startActivity(
                    jobId: jobId,
                    title: title,
                    jobType: jobType,
                    initialProgress: initialProgress,
                    initialMessage: initialMessage
                ) { [weak self] token in
                    // Send push token to Flutter via event channel
                    let event: [String: Any] = [
                        "type": "pushToken",
                        "jobId": jobId,
                        "token": token
                    ]
                    if let sink = self?.eventSink {
                        sink(event)
                    } else {
                        // Buffer token until Dart listener is ready
                        self?.pendingTokens.append(event)
                    }
                }

                result([
                    "activityId": activityId,
                    "jobId": jobId
                ])
            } catch {
                result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.2+", details: nil))
        }
    }

    // MARK: - Update Live Activity

    private func handleUpdateLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String,
                  let progress = args["progress"] as? Int,
                  let status = args["status"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }

            let message = args["message"] as? String
            let stageName = args["stageName"] as? String
            let stageIndex = args["stageIndex"] as? Int
            let stageTotal = args["stageTotal"] as? Int
            let eta = args["eta"] as? Int
            let resultUrl = args["resultUrl"] as? String

            Task {
                do {
                    let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                    try await bridge.updateActivity(
                        jobId: jobId,
                        progress: progress,
                        status: status,
                        message: message,
                        stageName: stageName,
                        stageIndex: stageIndex,
                        stageTotal: stageTotal,
                        eta: eta,
                        resultUrl: resultUrl
                    )
                    await MainActor.run {
                        result(true)
                    }
                } catch {
                    await MainActor.run {
                        result(FlutterError(code: "UPDATE_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.2+", details: nil))
        }
    }

    // MARK: - End Live Activity

    private func handleEndLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String,
                  let finalProgress = args["finalProgress"] as? Int,
                  let finalStatus = args["finalStatus"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }

            let message = args["message"] as? String
            let resultUrl = args["resultUrl"] as? String
            let errorMessage = args["errorMessage"] as? String
            let dismissAfter = args["dismissAfter"] as? Double ?? 300

            // CTA Button params
            var ctaButtonText: String? = nil
            var ctaDeepLink: String? = nil
            var ctaButtonStyle: String? = nil
            var ctaBackgroundColor: String? = nil
            var ctaTextColor: String? = nil
            var ctaCornerRadius: Int? = nil

            if let ctaButton = args["ctaButton"] as? [String: Any] {
                ctaButtonText = ctaButton["text"] as? String
                ctaDeepLink = ctaButton["deepLink"] as? String
                ctaButtonStyle = ctaButton["style"] as? String
                ctaBackgroundColor = ctaButton["backgroundColor"] as? String
                ctaTextColor = ctaButton["textColor"] as? String
                ctaCornerRadius = ctaButton["cornerRadius"] as? Int
            }

            Task {
                do {
                    let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                    try await bridge.endActivity(
                        jobId: jobId,
                        finalProgress: finalProgress,
                        finalStatus: finalStatus,
                        message: message,
                        resultUrl: resultUrl,
                        errorMessage: errorMessage,
                        dismissAfter: dismissAfter,
                        ctaButtonText: ctaButtonText,
                        ctaDeepLink: ctaDeepLink,
                        ctaButtonStyle: ctaButtonStyle,
                        ctaBackgroundColor: ctaBackgroundColor,
                        ctaTextColor: ctaTextColor,
                        ctaCornerRadius: ctaCornerRadius
                    )
                    await MainActor.run {
                        result(true)
                    }
                } catch {
                    await MainActor.run {
                        result(FlutterError(code: "END_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.2+", details: nil))
        }
    }

    // MARK: - Cancel Live Activity

    private func handleCancelLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing jobId argument", details: nil))
                return
            }

            Task {
                do {
                    let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                    await bridge.cancelActivity(jobId: jobId)
                    await MainActor.run {
                        result(true)
                    }
                } catch {
                    await MainActor.run {
                        result(FlutterError(code: "CANCEL_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.2+", details: nil))
        }
    }

    // MARK: - Is Activity Active

    private func handleIsActivityActive(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing jobId argument", details: nil))
                return
            }

            do {
                let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                result(bridge.isActivityActive(jobId: jobId))
            } catch {
                result(false)
            }
        } else {
            result(false)
        }
    }

    // MARK: - Get Active Activity IDs

    private func handleGetActiveActivityIds(result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            do {
                let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                result(bridge.getActiveActivityIds())
            } catch {
                result([String]())
            }
        } else {
            result([String]())
        }
    }

    // MARK: - Cancel All Activities

    private func handleCancelAllActivities(result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            Task {
                do {
                    let bridge = try SeennLiveActivityRegistry.shared.getBridge()
                    await bridge.cancelAllActivities()
                    await MainActor.run {
                        result(true)
                    }
                } catch {
                    await MainActor.run {
                        result(FlutterError(code: "CANCEL_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
        } else {
            result(true)
        }
    }

    // MARK: - Push Authorization (iOS 12+)

    private func handleGetPushAuthorizationStatus(result: @escaping FlutterResult) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status: String
            let isProvisional: Bool
            let canRequestFullAuthorization: Bool

            switch settings.authorizationStatus {
            case .notDetermined:
                status = "notDetermined"
                isProvisional = false
                canRequestFullAuthorization = false
            case .denied:
                status = "denied"
                isProvisional = false
                canRequestFullAuthorization = false
            case .authorized:
                status = "authorized"
                isProvisional = false
                canRequestFullAuthorization = false
            case .provisional:
                status = "provisional"
                isProvisional = true
                canRequestFullAuthorization = true
            case .ephemeral:
                status = "ephemeral"
                isProvisional = false
                canRequestFullAuthorization = false
            @unknown default:
                status = "notDetermined"
                isProvisional = false
                canRequestFullAuthorization = false
            }

            DispatchQueue.main.async {
                result([
                    "status": status,
                    "isProvisional": isProvisional,
                    "canRequestFullAuthorization": canRequestFullAuthorization
                ])
            }
        }
    }

    private func handleRequestProvisionalPushAuthorization(result: @escaping FlutterResult) {
        if #available(iOS 12.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .provisional]
            ) { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(
                            code: "PUSH_AUTH_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    } else {
                        if granted {
                            // Swizzle AppDelegate to capture device token
                            SeennPushTokenHandler.shared.swizzleAppDelegate()
                            // Register for remote notifications to get device token
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                        result(granted)
                    }
                }
            }
        } else {
            // iOS < 12: Provisional not supported, fall back to standard
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(
                            code: "PUSH_AUTH_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    } else {
                        if granted {
                            // Swizzle AppDelegate to capture device token
                            SeennPushTokenHandler.shared.swizzleAppDelegate()
                            // Register for remote notifications to get device token
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                        result(granted)
                    }
                }
            }
        }
    }

    private func handleRequestStandardPushAuthorization(result: @escaping FlutterResult) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "PUSH_AUTH_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    if granted {
                        // Swizzle AppDelegate to capture device token
                        SeennPushTokenHandler.shared.swizzleAppDelegate()
                        // Register for remote notifications to get device token
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    result(granted)
                }
            }
        }
    }
}

// MARK: - FlutterStreamHandler

extension SeennFlutterPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        // Flush any Live Activity tokens that arrived before Dart was ready
        for event in pendingTokens {
            events(event)
        }
        pendingTokens.removeAll()

        // Flush any device tokens that arrived before Dart was ready
        for event in pendingDeviceTokens {
            events(event)
        }
        pendingDeviceTokens.removeAll()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
