@testable import klaviyo_flutter_sdk
import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {
    func testBackgroundChannelStaysWithFirstHandlerUntilItsEngineDetaches() {
        let plugin = KlaviyoFlutterSdkPlugin.shared
        let previousChannel = plugin.backgroundChannel
        let previousRegistration = plugin.isBackgroundHandlerRegistered
        let first = TestRegistrar()
        let second = TestRegistrar()
        defer {
            first.detach()
            second.detach()
            plugin.backgroundChannel = previousChannel
            plugin.isBackgroundHandlerRegistered = previousRegistration
        }
        plugin.backgroundChannel = nil
        plugin.isBackgroundHandlerRegistered = false

        KlaviyoFlutterSdkPlugin.register(with: first)
        first.registerBackgroundHandler()
        KlaviyoFlutterSdkPlugin.register(with: second)
        plugin.backgroundChannel?.invokeMethod("handleBackgroundPushData", arguments: nil)
        XCTAssertEqual(first.binaryMessenger.sentChannels, ["klaviyo_sdk_background"])
        XCTAssertTrue(second.binaryMessenger.sentChannels.isEmpty)

        second.registerBackgroundHandler()
        plugin.backgroundChannel?.invokeMethod("handleBackgroundPushData", arguments: nil)
        XCTAssertEqual(
            first.binaryMessenger.sentChannels,
            ["klaviyo_sdk_background", "klaviyo_sdk_background"]
        )
        XCTAssertTrue(second.binaryMessenger.sentChannels.isEmpty)

        first.detach()
        XCTAssertNil(plugin.backgroundChannel)
        XCTAssertFalse(plugin.isBackgroundHandlerRegistered)

        second.registerBackgroundHandler()
        plugin.backgroundChannel?.invokeMethod("handleBackgroundPushData", arguments: nil)
        XCTAssertEqual(second.binaryMessenger.sentChannels, ["klaviyo_sdk_background"])
    }
}

private final class TestRegistrar: NSObject, FlutterPluginRegistrar {
    let binaryMessenger = TestMessenger()
    private var publishedValue: NSObject?
    var viewController: UIViewController? {
        nil
    }

    func messenger() -> FlutterBinaryMessenger {
        binaryMessenger
    }

    func textures() -> FlutterTextureRegistry {
        fatalError("No textures in this test")
    }

    func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {}
    func register(
        _ factory: FlutterPlatformViewFactory,
        withId factoryId: String,
        gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicy
    ) {}
    func publish(_ value: NSObject) {
        publishedValue = value
    }

    func valuePublished(byPlugin pluginKey: String) -> NSObject? {
        publishedValue
    }

    func addApplicationDelegate(_ delegate: FlutterPlugin) {}
    func addSceneDelegate(_ delegate: FlutterSceneLifeCycleDelegate) {}
    func lookupKey(forAsset asset: String) -> String {
        asset
    }

    func lookupKey(forAsset asset: String, fromPackage package: String) -> String {
        asset
    }

    func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {
        channel.setMethodCallHandler { call, reply in delegate.handle?(call, result: reply) }
    }

    func registerBackgroundHandler() {
        let call = FlutterMethodCall(methodName: "registerBackgroundPushDataHandler", arguments: nil)
        let message = FlutterStandardMethodCodec.sharedInstance().encode(call)
        binaryMessenger.handlers["klaviyo_sdk"]?(message) { _ in }
    }

    func detach() {
        _ = publishedValue?.perform(NSSelectorFromString("detachFromEngineForRegistrar:"), with: self)
        publishedValue = nil
    }
}

private final class TestMessenger: NSObject, FlutterBinaryMessenger {
    var handlers: [String: FlutterBinaryMessageHandler] = [:]
    private(set) var sentChannels: [String] = []

    func send(onChannel channel: String, message: Data?) {
        sentChannels.append(channel)
    }

    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
        send(onChannel: channel, message: message)
    }

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler?
    ) -> FlutterBinaryMessengerConnection {
        handlers[channel] = handler
        return 1
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
