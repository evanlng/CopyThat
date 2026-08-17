// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CopyThat",
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
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "ClipboardFeedbackTests",
            dependencies: ["ClipboardFeedback"],
            path: "ClipboardFeedbackTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
