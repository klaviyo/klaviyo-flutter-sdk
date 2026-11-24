// swift-tools-version: 5.9
import Foundation
import PackageDescription

// Mobile Inbox is opt-in while the native KlaviyoInbox module is unreleased.
//
// Swift Package Manager cannot toggle a target's product dependencies from the
// host's build settings, but it does evaluate a package manifest in the
// environment of the command that resolves it, and that includes a dependency's
// own manifest. So a host opts in by setting KLAVIYO_INCLUDE_INBOX=true in the
// environment of `xcodebuild`/`swift build`, the same name the podspec reads.
// Unset — the default — the product is not linked and the plugin reports
// INBOX_UNAVAILABLE, exactly as the CocoaPods and Gradle paths do.
//
// The alternative, an always-on product, would force every SPM host to fetch
// and link the inbox module whether or not it can be used yet, so it was
// rejected.
let includeInbox = ProcessInfo.processInfo.environment["KLAVIYO_INCLUDE_INBOX"] == "true"

var inboxDependencies: [PackageDescription.Target.Dependency] = []
if includeInbox {
    inboxDependencies.append(.product(name: "KlaviyoInbox", package: "klaviyo-swift-sdk"))
}

let package = Package(
    name: "klaviyo_flutter_sdk",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "klaviyo-flutter-sdk", targets: ["klaviyo_flutter_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(
            url: "https://github.com/klaviyo/klaviyo-swift-sdk",
            branch: "rel/5.7.0"
        )
    ],
    targets: [
        .target(
            name: "klaviyo_flutter_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "KlaviyoSwift", package: "klaviyo-swift-sdk"),
                .product(name: "KlaviyoForms", package: "klaviyo-swift-sdk"),
                .product(name: "KlaviyoLocation", package: "klaviyo-swift-sdk")
            ] + inboxDependencies,
            resources: [
                .process("klaviyo-sdk-configuration.plist")
            ]
        )
    ]
)
