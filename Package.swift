// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlowDictation",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FlowDictation",
            path: "Sources/FlowDictation",
            exclude: [
                "Resources/Info.plist",
                "Resources/AppIcon.icns"
            ],
            resources: [
                .copy("Resources/FlowDictation.entitlements")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
