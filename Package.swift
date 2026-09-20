// swift-tools-version: 5.9
import Foundation
import PackageDescription

// Apps override this dependency with the @capacitor/ios they installed. To build this package on its own
// against a local runtime, point CAPACITOR_IOS_PATH at it.
let capacitor: Package.Dependency
if let path = ProcessInfo.processInfo.environment["CAPACITOR_IOS_PATH"] {
    capacitor = .package(name: "capacitor-swift-pm", path: path)
} else {
    capacitor = .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
}

let package = Package(
    name: "CapacitorCommunityPhotoviewer",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "CapacitorCommunityPhotoviewer",
            targets: ["PhotoViewerPlugin"])
    ],
    dependencies: [
        capacitor,
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.20.0"),
        .package(url: "https://github.com/yuriiik/ISVImageScrollView.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "PhotoViewerPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "ISVImageScrollView", package: "ISVImageScrollView")
            ],
            path: "ios/Sources/PhotoViewerPlugin"),
        .testTarget(
            name: "PhotoViewerPluginTests",
            dependencies: ["PhotoViewerPlugin"],
            path: "ios/Tests/PhotoViewerPluginTests")
    ]
)
