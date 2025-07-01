import Flutter
import KlaviyoSwift
import KlaviyoForms
import UIKit

public class KlaviyoFlutterSdkPlugin: NSObject, FlutterPlugin {
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "klaviyo_sdk", binaryMessenger: registrar.messenger())
    let instance = KlaviyoFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let eventChannel = FlutterEventChannel(
      name: "klaviyo_events", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any],
        let apiKey = args["apiKey"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS", message: "Invalid arguments for initialize", details: nil))
        return
      }
      KlaviyoSDK().initialize(with: apiKey)
      result(nil)

    case "setProfile":
      guard let args = call.arguments as? [String: Any],
        let profileData = args["profile"] as? [String: Any]
      else {
        result(
          FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid profile data", details: nil))
        return
      }
      let profile = Profile(
        email: profileData["email"] as? String,
        phoneNumber: profileData["phone_number"] as? String,
        externalId: profileData["external_id"] as? String,
        firstName: profileData["first_name"] as? String,
        lastName: profileData["last_name"] as? String,
        organization: profileData["organization"] as? String,
        title: profileData["title"] as? String,
        image: profileData["image"] as? String,
        location: nil, // TODO: handle location if needed
        properties: profileData["properties"] as? [String: Any]
      )
      KlaviyoSDK().set(profile: profile)
      result(nil)

    case "setEmail":
      guard let args = call.arguments as? [String: Any],
        let email = args["email"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid email", details: nil))
        return
      }
      // Not directly supported: must use setProfile with new Profile
      result(FlutterError(code: "NOT_SUPPORTED", message: "Use setProfile instead", details: nil))

    case "setPhoneNumber":
      guard let args = call.arguments as? [String: Any],
        let phoneNumber = args["phoneNumber"] as? String
      else {
        result(
          FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid phone number", details: nil))
        return
      }
      // Not directly supported: must use setProfile with new Profile
      result(FlutterError(code: "NOT_SUPPORTED", message: "Use setProfile instead", details: nil))

    case "setExternalId":
      guard let args = call.arguments as? [String: Any],
        let externalId = args["externalId"] as? String
      else {
        result(
          FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid external ID", details: nil))
        return
      }
      // Not directly supported: must use setProfile with new Profile
      result(FlutterError(code: "NOT_SUPPORTED", message: "Use setProfile instead", details: nil))

    case "setProfileProperties":
      guard let args = call.arguments as? [String: Any],
        let properties = args["properties"] as? [String: Any]
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid properties", details: nil))
        return
      }
      // Not directly supported: must use setProfile with new Profile
      result(FlutterError(code: "NOT_SUPPORTED", message: "Use setProfile instead", details: nil))

    case "trackEvent":
      guard let args = call.arguments as? [String: Any],
        let eventData = args["event"] as? [String: Any],
        let name = eventData["name"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid event data", details: nil))
        return
      }
      let properties = eventData["properties"] as? [String: Any] ?? [:]
      let value = eventData["value"] as? Double
      let event = Event(
        name: .customEvent(name),
        properties: properties,
        value: value
      )
      KlaviyoSDK().create(event: event)
      result(nil)

    case "registerForPushNotifications":
      // No-op: handled by iOS system
      result(nil)

    case "setPushToken":
      // No-op: handled by iOS system
      result(nil)

    case "getPushToken":
      // Not directly supported
      result([
        "token": "",
        "environment": "production",
        "platform": "ios",
        "createdAt": Date().description,
        "isActive": false,
      ])

    case "registerForInAppForms":
      // Register for in-app forms
      DispatchQueue.main.async {
        KlaviyoSDK().registerForInAppForms()
      }
      result(nil)

    case "showForm":
      // Not supported in v5.0.0; forms are shown automatically based on targeting
      result(FlutterError(code: "NOT_SUPPORTED", message: "Direct showForm is not supported in v5.0.0; forms are shown automatically.", details: nil))
    case "hideForm":
      // Not supported in v5.0.0; forms are hidden automatically
      result(FlutterError(code: "NOT_SUPPORTED", message: "Direct hideForm is not supported in v5.0.0; forms are hidden automatically.", details: nil))

    case "resetProfile":
      KlaviyoSDK().resetProfile()
      result(nil)

    case "setLogLevel":
      // Not directly supported in v5.0.0
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension KlaviyoFlutterSdkPlugin: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
