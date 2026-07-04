// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "ParcelOps",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "ParcelOps", targets: ["ParcelOps"])
  ],
  dependencies: [
    .package(url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc.git", exact: "2.12.1"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS.git", exact: "9.2.0")
  ],
  targets: [
    .executableTarget(
      name: "ParcelOps",
      dependencies: [
        .product(name: "MSAL", package: "microsoft-authentication-library-for-objc"),
        .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
      ],
      path: "Sources"
    )
  ]
)
