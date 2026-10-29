// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeviceHubCapture",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DeviceHubCapture")
    ]
)
