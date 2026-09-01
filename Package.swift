// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VicEmergencyMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VicEmergencyMonitor",
            path: "Sources/VicEmergencyMonitor"
        )
    ]
)
