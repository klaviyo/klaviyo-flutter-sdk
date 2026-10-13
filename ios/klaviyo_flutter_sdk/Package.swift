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
            revision: "db58bbee45258de84cb4b0d5bc6fcd1a7d9a826d"
        )
    ],
    targets: [
        .target(
            name: "klaviyo_flutter_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "KlaviyoCore", package: "klaviyo-swift-sdk"),
                .product(name: "KlaviyoSwift", package: "klaviyo-swift-sdk"),
                .product(name: "KlaviyoForms", package: "klaviyo-swift-sdk")
            ],
            resources: [
                .process("klaviyo-sdk-configuration.plist")
            ]
        )
    ]
)
