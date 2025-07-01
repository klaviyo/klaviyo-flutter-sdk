import Flutter
import KlaviyoSwift
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

      do {
        print("🔍 KlaviyoFlutterSdk: Initializing with API key: \(apiKey)")
        Klaviyo.setupWithPublicAPIKey(apiKey: apiKey)
        print("✅ KlaviyoFlutterSdk: Initialization completed")
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "INIT_ERROR", message: "Failed to initialize Klaviyo",
            details: error.localizedDescription))
      }

    case "setProfile":
      guard let args = call.arguments as? [String: Any],
        let profileData = args["profile"] as? [String: Any]
      else {
        result(
          FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid profile data", details: nil))
        return
      }

      do {
        // Convert profile data to NSDictionary for the old API
        let personDictionary = NSMutableDictionary()

        if let email = profileData["email"] as? String {
          personDictionary["$email"] = email
        }
        if let firstName = profileData["first_name"] as? String {
          personDictionary["$first_name"] = firstName
        }
        if let lastName = profileData["last_name"] as? String {
          personDictionary["$last_name"] = lastName
        }
        if let phoneNumber = profileData["phone_number"] as? String {
          personDictionary["$phone_number"] = phoneNumber
        }
        if let externalId = profileData["external_id"] as? String {
          personDictionary["$id"] = externalId
        }
        if let organization = profileData["organization"] as? String {
          personDictionary["$organization"] = organization
        }
        if let title = profileData["title"] as? String {
          personDictionary["$title"] = title
        }
        if let image = profileData["image"] as? String {
          personDictionary["$image"] = image
        }

        // Add custom properties
        if let properties = profileData["properties"] as? [String: Any] {
          for (key, value) in properties {
            personDictionary[key] = value
          }
        }

        print("🔍 KlaviyoFlutterSdk: Setting profile with data: \(personDictionary)")
        Klaviyo.sharedInstance.trackPersonWithInfo(personDictionary: personDictionary)
        print("✅ KlaviyoFlutterSdk: Profile tracking completed")
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "PROFILE_ERROR", message: "Failed to set profile",
            details: error.localizedDescription))
      }

    case "setEmail":
      guard let args = call.arguments as? [String: Any],
        let email = args["email"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid email", details: nil))
        return
      }

      do {
        Klaviyo.sharedInstance.setUpUserEmail(userEmail: email)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "EMAIL_ERROR", message: "Failed to set email", details: error.localizedDescription
          ))
      }

    case "setPhoneNumber":
      guard let args = call.arguments as? [String: Any],
        let phoneNumber = args["phoneNumber"] as? String
      else {
        result(
          FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid phone number", details: nil))
        return
      }

      do {
        // Set phone number via profile tracking
        let personDictionary = NSDictionary(dictionary: ["$phone_number": phoneNumber])
        print("🔍 KlaviyoFlutterSdk: Setting phone number: \(phoneNumber)")
        Klaviyo.sharedInstance.trackPersonWithInfo(personDictionary: personDictionary)
        print("✅ KlaviyoFlutterSdk: Phone number tracking completed")
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "PHONE_ERROR", message: "Failed to set phone number",
            details: error.localizedDescription))
      }

    case "setExternalId":
      guard let args = call.arguments as? [String: Any],
        let externalId = args["externalId"] as? String
      else {
        result(
          FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid external ID", details: nil))
        return
      }

      do {
        Klaviyo.sharedInstance.setUpCustomerID(id: externalId)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "EXTERNAL_ID_ERROR", message: "Failed to set external ID",
            details: error.localizedDescription))
      }

    case "setProfileProperties":
      guard let args = call.arguments as? [String: Any],
        let properties = args["properties"] as? [String: Any]
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid properties", details: nil))
        return
      }

      do {
        // Set properties via profile tracking
        let personDictionary = NSDictionary(dictionary: properties)
        print("🔍 KlaviyoFlutterSdk: Setting properties: \(properties)")
        Klaviyo.sharedInstance.trackPersonWithInfo(personDictionary: personDictionary)
        print("✅ KlaviyoFlutterSdk: Properties tracking completed")
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "PROPERTIES_ERROR", message: "Failed to set profile properties",
            details: error.localizedDescription))
      }

    case "trackEvent":
      guard let args = call.arguments as? [String: Any],
        let eventData = args["event"] as? [String: Any],
        let name = eventData["name"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid event data", details: nil))
        return
      }

      do {
        let properties = eventData["properties"] as? [String: Any] ?? [:]
        let customerProperties = eventData["customer_properties"] as? [String: Any]

        // Convert to NSDictionary for the old API
        let propertiesDict = NSDictionary(dictionary: properties)
        let customerPropertiesDict =
          customerProperties != nil ? NSDictionary(dictionary: customerProperties!) : nil

        print("🔍 KlaviyoFlutterSdk: Tracking event: \(name) with properties: \(propertiesDict)")
        Klaviyo.sharedInstance.trackEvent(
          event: name,
          customerProperties: customerPropertiesDict,
          propertiesDict: propertiesDict,
          eventDate: nil
        )
        print("✅ KlaviyoFlutterSdk: Event tracking completed")
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "TRACK_ERROR", message: "Failed to track event",
            details: error.localizedDescription))
      }

    case "registerForPushNotifications":
      do {
        // Push notification registration is handled automatically by the SDK
        // when the app requests permission
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "PUSH_REGISTER_ERROR", message: "Failed to register for push notifications",
            details: error.localizedDescription))
      }

    case "setPushToken":
      guard let args = call.arguments as? [String: Any],
        let token = args["token"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid push token", details: nil))
        return
      }

      do {
        // Convert string token to Data
        if let tokenData = token.data(using: .utf8) {
          Klaviyo.sharedInstance.addPushDeviceToken(deviceToken: tokenData)
        }
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "PUSH_TOKEN_ERROR", message: "Failed to set push token",
            details: error.localizedDescription))
      }

    case "getPushToken":
      do {
        // The SDK doesn't provide a direct method to get the push token
        // This would need to be managed by the Flutter app
        result([
          "token": "",
          "environment": "production",
          "platform": "ios",
          "createdAt": Date().description,
          "isActive": false,
        ])
      } catch {
        result(
          FlutterError(
            code: "PUSH_TOKEN_ERROR", message: "Failed to get push token",
            details: error.localizedDescription))
      }

    case "registerForInAppForms":
      guard let args = call.arguments as? [String: Any]
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        return
      }

      do {
        // In-app forms are not supported in this version of KlaviyoSwift
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "FORMS_ERROR", message: "Failed to register for in-app forms",
            details: error.localizedDescription))
      }

    case "showForm":
      guard let args = call.arguments as? [String: Any],
        let formId = args["formId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid form ID", details: nil))
        return
      }

      do {
        // In-app forms are not supported in this version of KlaviyoSwift
        result(false)
      } catch {
        result(
          FlutterError(
            code: "FORM_ERROR", message: "Failed to show form",
            details: error.localizedDescription))
      }

    case "hideForm":
      guard let args = call.arguments as? [String: Any],
        let formId = args["formId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid form ID", details: nil))
        return
      }

      do {
        // In-app forms are not supported in this version of KlaviyoSwift
        result(false)
      } catch {
        result(
          FlutterError(
            code: "FORM_ERROR", message: "Failed to hide form",
            details: error.localizedDescription))
      }

    case "resetProfile":
      do {
        // Reset profile by clearing email and customer ID
        Klaviyo.sharedInstance.setUpUserEmail(userEmail: "")
        Klaviyo.sharedInstance.setUpCustomerID(id: "")
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "RESET_ERROR", message: "Failed to reset profile",
            details: error.localizedDescription))
      }

    case "setLogLevel":
      guard let args = call.arguments as? [String: Any],
        let logLevel = args["logLevel"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid log level", details: nil))
        return
      }

      do {
        // Log level is not configurable in this version of KlaviyoSwift
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "LOG_LEVEL_ERROR", message: "Failed to set log level",
            details: error.localizedDescription))
      }

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
