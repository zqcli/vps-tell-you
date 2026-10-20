import Flutter
import UIKit

/// `vps_tell_you/background`: lets Dart ask iOS for the short extra run time
/// that `UIApplication.beginBackgroundTask(withName:expirationHandler:)`
/// grants, so an SSH session survives a brief trip to another app.
///
/// This is the plain background-task API: no background mode, no audio, VoIP
/// or location. The system decides the duration (typically about 30 s on
/// iOS 13+), readable through `backgroundTimeRemaining`.
///
/// Methods (all on the main thread):
/// - `begin(name)` -> `{token: Int, remainingSeconds: Double}`
/// - `end(token)` -> nil (unknown tokens are ignored)
/// - `remaining()` -> Double (a huge value while the app is in the foreground)
/// Native -> Dart: `expiring({token})`, a best-effort notification posted just
/// before the task is ended synchronously in the expiration handler.
final class BackgroundTimeChannel {
  static let name = "vps_tell_you/background"

  private let channel: FlutterMethodChannel
  private var tasks: [Int: UIBackgroundTaskIdentifier] = [:]
  private var nextToken = 1

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "begin":
      let args = call.arguments as? [String: Any]
      begin(name: args?["name"] as? String ?? "ssh-session", result: result)
    case "end":
      if let token = (call.arguments as? [String: Any])?["token"] as? Int {
        finish(token)
      }
      result(nil)
    case "remaining":
      result(UIApplication.shared.backgroundTimeRemaining)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func begin(name: String, result: FlutterResult) {
    let token = nextToken
    nextToken += 1
    let id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
      self?.expired(token)
    }
    guard id != .invalid else {
      result(FlutterError(code: "unavailable", message: "The system refused a background task", details: nil))
      return
    }
    tasks[token] = id
    result([
      "token": token,
      "remainingSeconds": UIApplication.shared.backgroundTimeRemaining,
    ])
  }

  /// Expiration handler. iOS may suspend the process as soon as this handler
  /// returns, and requires the task to be ended before then, so the task is
  /// ended synchronously here. The `expiring` message is only a best-effort
  /// heads-up for Dart (which also runs its own safety timer from the measured
  /// budget); its reply is not awaited and an unanswered message costs nothing.
  private func expired(_ token: Int) {
    guard tasks[token] != nil else { return }
    channel.invokeMethod("expiring", arguments: ["token": token])
    finish(token)
  }

  /// Ends a task exactly once.
  private func finish(_ token: Int) {
    guard let id = tasks.removeValue(forKey: token) else { return }
    UIApplication.shared.endBackgroundTask(id)
  }
}
