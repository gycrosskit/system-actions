// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GYCWindowPolicy",
    platforms: [.iOS(.v14)],
    products: [.library(name: "GYCWindowPolicy", targets: ["GYCWindowPolicy"])],
    targets: [.target(name: "GYCWindowPolicy", path: "ios/Sources/GYCWindowPolicy")]
)
