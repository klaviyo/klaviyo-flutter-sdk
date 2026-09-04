// swift-tools-version: 5.9
import PackageDescription

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
            .upToNextMinor(from: "5.4.1")
        )
    ],
    targets: [
        .target(
            name: "klaviyo_flutter_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "KlaviyoSwift", package: "klaviyo-swift-sdk"),
                .product(name: "KlaviyoForms", package: "klaviyo-swift-sdk")
            ],
            resources: [
                .process("klaviyo-sdk-configuration.plist")
            ]
        )
    ]
)
