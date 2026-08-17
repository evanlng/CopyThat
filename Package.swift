// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CopyThat",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CopyThat", targets: ["ClipboardFeedback"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardFeedback",
            path: "ClipboardFeedback",
            exclude: [
                "Info.plist",
                "AppIcon.icon",
                "ClipboardFeedback.entitlements"
            ]
        ),
        .testTarget(
            name: "ClipboardFeedbackTests",
            dependencies: ["ClipboardFeedback"],
            path: "ClipboardFeedbackTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
