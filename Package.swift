// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-combinators",
    products: [
        .library(name: "Combinators", targets: ["Combinators"]),
        .executable(name: "ski", targets: ["ski"]),
    ],
    targets: [
        .target(name: "Combinators"),
        .executableTarget(name: "ski", dependencies: ["Combinators"]),
        .testTarget(name: "CombinatorsTests", dependencies: ["Combinators"]),
    ],
    swiftLanguageModes: [.v6]
)
