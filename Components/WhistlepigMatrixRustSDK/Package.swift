// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "WhistlepigMatrixRustSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "MatrixRustSDK", type: .dynamic, targets: ["MatrixRustSDK"])
    ],
    targets: [
        .binaryTarget(name: "MatrixSDKFFI", path: "Artifacts/MatrixSDKFFI.xcframework"),
        .target(name: "MatrixRustSDK", dependencies: ["MatrixSDKFFI"])
    ]
)
