// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LedgerCLI",
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
