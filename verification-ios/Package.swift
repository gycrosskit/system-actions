// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "WindowPolicyConsumer",
    platforms: [.iOS(.v14)],
    products: [.library(name: "WindowPolicyConsumer", targets: ["WindowPolicyConsumer"])],
    dependencies: [.package(url: "https://github.com/gycrosskit/system-actions.git", exact: "0.2.0-rc.2")],
    targets: [.target(name: "WindowPolicyConsumer", dependencies: [.product(name: "GYCWindowPolicy", package: "system-actions")])]
)
