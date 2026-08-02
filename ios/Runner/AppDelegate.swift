import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications: without this, iOS never calls the plugin's
    // foreground-presentation handler, so local notifications silently don't show a banner while
    // the app is open (they'd only land in Notification Center once backgrounded, if at all).
    // `as?` matches the plugin's own documented setup snippet — FlutterAppDelegate doesn't
    // statically declare UNUserNotificationCenterDelegate conformance, so a plain assignment
    // risks a compile error; the plugin wires actual conformance in via its own runtime registrant.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
