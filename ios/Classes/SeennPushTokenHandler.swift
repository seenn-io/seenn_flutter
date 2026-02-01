import Foundation
import UIKit

/// Singleton handler for device push tokens
///
/// This class uses method swizzling to intercept AppDelegate's
/// `didRegisterForRemoteNotificationsWithDeviceToken` callback.
///
/// Usage:
/// The SDK automatically swizzles AppDelegate when `requestProvisionalPushAuthorization()`
/// is called. No manual setup required in AppDelegate.
@objc public class SeennPushTokenHandler: NSObject {

    @objc public static let shared = SeennPushTokenHandler()

    private var pendingDeviceTokens: [String] = []
    private var deviceTokenCallback: ((String) -> Void)?
    private var hasSwizzled = false
    private var originalImplementation: IMP?

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Set callback for device push tokens
    func setDeviceTokenCallback(_ callback: @escaping (String) -> Void) {
        self.deviceTokenCallback = callback
        // Flush any pending tokens
        for token in pendingDeviceTokens {
            callback(token)
        }
        pendingDeviceTokens.removeAll()
    }

    /// Called when a device token is received
    @objc public func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        if let callback = deviceTokenCallback {
            callback(token)
        } else {
            // Buffer token until callback is set
            pendingDeviceTokens.append(token)
        }
    }

    /// Perform method swizzling on AppDelegate
    ///
    /// This intercepts `application:didRegisterForRemoteNotificationsWithDeviceToken:`
    /// to capture device tokens while still allowing other SDKs (OneSignal, Firebase) to work.
    func swizzleAppDelegate() {
        guard !hasSwizzled else { return }
        hasSwizzled = true

        guard let appDelegate = UIApplication.shared.delegate,
              let appDelegateClass = object_getClass(appDelegate) else {
            return
        }

        let originalSelector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
        let swizzledSelector = #selector(SeennPushTokenHandler.seenn_application(_:didRegisterForRemoteNotificationsWithDeviceToken:))

        // Get original method (if it exists)
        if let originalMethod = class_getInstanceMethod(appDelegateClass, originalSelector) {
            originalImplementation = method_getImplementation(originalMethod)
        }

        // Add our method to AppDelegate class
        guard let swizzledMethod = class_getInstanceMethod(SeennPushTokenHandler.self, swizzledSelector) else {
            return
        }

        let didAddMethod = class_addMethod(
            appDelegateClass,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod {
            // Method was added (no existing implementation)
            // Nothing more to do
        } else if let originalMethod = class_getInstanceMethod(appDelegateClass, originalSelector) {
            // Method exists, swap implementations
            method_setImplementation(originalMethod, method_getImplementation(swizzledMethod))
        }
    }

    // MARK: - Swizzled Method

    @objc func seenn_application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Capture token for Seenn
        SeennPushTokenHandler.shared.handleDeviceToken(deviceToken)

        // Call original implementation if it exists (for OneSignal, Firebase, etc.)
        if let originalImp = SeennPushTokenHandler.shared.originalImplementation {
            typealias OriginalFunction = @convention(c) (AnyObject, Selector, UIApplication, Data) -> Void
            let originalFunc = unsafeBitCast(originalImp, to: OriginalFunction.self)
            let selector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
            originalFunc(self, selector, application, deviceToken)
        }
    }
}
