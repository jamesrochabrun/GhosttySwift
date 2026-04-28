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
      url: "https://github.com/jamesrochabrun/GhosttySwift/releases/download/1.0.3/GhosttyKit.xcframework.zip",
      checksum: "476c7c8f7e3bf543650c74e35c72d4572a10572321b42e6237341c8a12ab50e6"
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
