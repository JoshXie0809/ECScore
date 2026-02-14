// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let crossModuleOptimizationSettings: [SwiftSetting] = [
    .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
]

let packagePlatforms: [SupportedPlatform]?
#if os(macOS)
    packagePlatforms = [.macOS(.v15)]
#else
    packagePlatforms = nil // Linux platforms
#endif

var packageTargets: [Target] = [
    .target(
        name: "ECScore",
        dependencies: ["ECScoreMacros"],
        swiftSettings: crossModuleOptimizationSettings
    ),
    .macro(
        name: "ECScoreMacros",
        dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        ]
    ),
    .executableTarget(
        name: "Game7Systems",
        dependencies: ["ECScore"],
        path: "Sources/Game7Systems",
        swiftSettings: crossModuleOptimizationSettings
    ),
    .testTarget(
        name: "ECScoreTests",
        dependencies: ["ECScore"]
    ),
    .testTarget(
        name: "ScedulerTests",
        dependencies: ["ECScore"]
    )
]

#if os(macOS)
packageTargets.append(
    .executableTarget(
        name: "VBPFMetalLab",
        dependencies: ["ECScore"],
        path: "Sources/VBPFMetalLab",
        swiftSettings: crossModuleOptimizationSettings,
        linkerSettings: [
            .linkedFramework("Metal"),
            .linkedFramework("MetalKit"),
            .linkedFramework("QuartzCore")
        ]
    )
)
#endif

let package = Package(
    name: "ECScore",
    platforms: packagePlatforms,
    products: [
        .library(name: "ECScore", targets: ["ECScore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
    ],
    targets: packageTargets
)