// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CompanyParcelTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CompanyParcelTracker", targets: ["CompanyParcelTracker"])
    ],
    targets: [
        .executableTarget(
            name: "CompanyParcelTracker",
            path: "Sources"
        )
    ]
)
