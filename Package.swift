// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "GhosttySwift",
  platforms: [.macOS(.v14)],
  products: [
    .library(
      name: "GhosttySwift",
      targets: ["GhosttySwift"]
    ),
    .executable(
      name: "GhosttySwiftSampleApp",
      targets: ["GhosttySwiftSampleApp"]
    ),
  ],
  targets: [
    .binaryTarget(
      name: "GhosttyKit",
      url: "https://github.com/jamesrochabrun/GhosttySwift/releases/download/1.0.10/GhosttyKit.xcframework.zip",
      checksum: "7dbea79cdc8e3f27b62f56f076ee3753b21b147f9fd81f18c091c8d2df344a7e"
    ),
    .target(
      name: "GhosttySwift",
      dependencies: ["GhosttyKit"],
      resources: [
        .copy("Resources/share"),
      ],
      linkerSettings: [
        .linkedFramework("Carbon"),
        .linkedLibrary("c++"),
      ]
    ),
    .executableTarget(
      name: "GhosttySwiftSampleApp",
      dependencies: ["GhosttySwift"]
    ),
    .testTarget(
      name: "GhosttySwiftTests",
      dependencies: ["GhosttySwift"]
    ),
  ]
)
