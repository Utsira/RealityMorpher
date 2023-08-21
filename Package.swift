// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealityMorpher",
	platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(
            name: "RealityMorpher",
            targets: ["RealityMorpher"]),
    ],
    targets: [
        .target(
			name: "RealityMorpher", dependencies: ["RealityMorpherKernels"]
		),
		.target(name: "RealityMorpherKernels"),
        .testTarget(
            name: "RealityMorpherTests",
            dependencies: ["RealityMorpher"]),
    ]
)
