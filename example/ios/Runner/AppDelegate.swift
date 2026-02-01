import Flutter
import UIKit
import seenn_flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register the Live Activity bridge
        // This is required for Live Activity to work correctly.
        // The bridge implementation uses YOUR SeennJobAttributes type,
        // which is shared with your Widget Extension.
        if #available(iOS 16.2, *) {
            SeennLiveActivityRegistry.shared.register(SeennLiveActivityBridgeImpl.shared)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
