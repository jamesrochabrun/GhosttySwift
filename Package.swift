// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "GhosttySwiftPermissive",
  platforms: [.macOS(.v13)],
  products: [
    .library(
      name: "GhosttySwiftPermissive",
      targets: ["GhosttySwiftPermissive"]
    ),
    .executable(
      name: "GhosttySwiftPermissiveSampleApp",
      targets: ["GhosttySwiftPermissiveSampleApp"]
    ),
  ],
  targets: [
    .binaryTarget(
      name: "GhosttyKit",
      path: "Frameworks/GhosttyKit.xcframework"
    ),
    .target(
      name: "GhosttySwiftPermissive",
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
      name: "GhosttySwiftPermissiveSampleApp",
      dependencies: ["GhosttySwiftPermissive"]
    ),
    .testTarget(
      name: "GhosttySwiftPermissiveTests",
      dependencies: ["GhosttySwiftPermissive"]
    ),
  ]
)
