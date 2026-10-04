// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "WindowPolicyConsumer",
    platforms: [.iOS(.v14)],
    products: [.library(name: "WindowPolicyConsumer", targets: ["WindowPolicyConsumer"])],
    dependencies: [.package(name: "GYCWindowPolicy", path: "..")],
    targets: [.target(name: "WindowPolicyConsumer", dependencies: [.product(name: "GYCWindowPolicy", package: "GYCWindowPolicy")])]
)
