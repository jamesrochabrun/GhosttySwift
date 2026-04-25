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
      path: "Frameworks/GhosttyKit.xcframework"
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
