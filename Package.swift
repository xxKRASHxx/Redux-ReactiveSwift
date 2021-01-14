// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ReduxReactiveSwift",
  platforms: [
    .macOS(.v10_10), .iOS(.v9), .tvOS(.v9), .watchOS(.v2)
  ],
  products: [
    .library(name: "ReduxReactiveSwift", targets: ["ReduxReactiveSwift"])
  ],
  dependencies: [
    .package(
      name: "ReactiveSwift",
      url: "https://github.com/ReactiveCocoa/ReactiveSwift.git",
      .upToNextMajor(from: "6.5.0")
    )
  ],
  targets: [
    .target(
      name: "ReduxReactiveSwift",
      dependencies: ["ReactiveSwift"],
      path: "Redux-ReactiveSwift/Classes"
    )
  ]
)
