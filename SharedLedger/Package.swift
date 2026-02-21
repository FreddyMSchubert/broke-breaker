// swift-tools-version: 5.9
import PackageDescription

let package = Package(
	name: "SharedLedger",
	platforms: [
		.iOS(.v16), .macOS(.v13)
		// Windows supported by SwiftPM; no platform entry needed.
	],
	products: [
		.library(name: "SharedLedger", targets: ["SharedLedger"])
	],
	dependencies: [
		// GRDB (SQLite)
		.package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
	],
	targets: [
		.target(
			name: "SharedLedger",
			dependencies: [
				.product(name: "GRDB", package: "GRDB.swift")
			]
		)
	]
)