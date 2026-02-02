// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

import PackageDescription

// 1. 根據環境動態決定平台陣列
let packagePlatforms: [SupportedPlatform]?
#if os(macOS)
    packagePlatforms = [.macOS(.v15)]
#else
    packagePlatforms = nil // Linux 不需要指定，給空陣列即可
#endif

let package = Package(
    name: "ECScore",
    platforms: packagePlatforms,
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ECScore",
            targets: ["ECScore"]
        ),
    ],
    dependencies: [
        // Swift Macro 一定要用
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "600.0.0"
        ),
    ],

    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ECScore",
            dependencies: ["ECScoreMacros"]
        ),

        // ✅ 新增：Macro target
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
            dependencies: ["ECScore", "ECScoreMacros"],
            path: "Sources/Game7Systems"
        ),

        .testTarget(
            name: "ECScoreTests",
            dependencies: ["ECScore"]
        ),
    ]
    
)
