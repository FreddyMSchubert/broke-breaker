import PackageDescription

let package = Package(
		name: "LedgerCLI",
		dependencies: [
			.package(path: "../SharedLedger")
	],
	targets: [
		.executableTarget(
			name: "LedgerCLI",
			dependencies: [
				"SharedLedger"
			]
		)
	]
)
