// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageSegmenter",
    platforms: [
        .iOS(.v16)  // ← Add this to target iOS
    ],
    products: [
        .library(name: "ImageSegmenter", targets: ["ImageSegmenter"])
    ],
    targets: [
        .target(
            name: "ImageSegmenter",
            path: ".",
            exclude: [
                "Base.lproj",
                "Assets.xcassets",
                "Info.plist",
                "AppDelegate.swift",
                "SceneDelegate.swift",
                ".build",
                "Tests"
            ]
        ),
        .testTarget(
            name: "Tests",
            dependencies: ["ImageSegmenter"]
        )
    ]
)
