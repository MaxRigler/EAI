// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "E-AI",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "E-AI", targets: ["E-AI"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift", from: "2.0.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.6.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2")
    ],
    targets: [
        .target(
            name: "E-AI",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "KeychainAccess", package: "KeychainAccess")
            ]
        )
    ]
)
