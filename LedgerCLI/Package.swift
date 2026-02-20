// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LedgerCLI", targets: ["LedgerCLI"])
    ],
    dependencies: [
        .package(path: "../SharedLedger")
    ],
    targets: [
        .executableTarget(
            name: "LedgerCLI",
            dependencies: ["SharedLedger"]
        )
    ]
)
