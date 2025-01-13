// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "CoreUTM",
	platforms: [
		.macOS(.v11),
		.iOS(.v14),
	],
	products: [
		.library(name: "CoreUTM", targets: ["CoreUTM"]),
	],
	dependencies: [
		.package(url: "https://github.com/utmapp/QEMUKit.git", branch: "main"),
		.package(url: "https://github.com/utmapp/CocoaSpice.git", branch: "main"),
	],
	targets: [
		.target(name: "OpenSSL"),

		.target(
			name: "CoreUTM",
			dependencies: [
				.product(name: "QEMUKit", package: "QEMUKit"),
				.product(name: "CocoaSpice", package: "CocoaSpice"),
				"OpenSSL",
			],
			cSettings: [
				.define("WITH_USB"),
			]),
	]
)
