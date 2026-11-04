// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AirPodClicker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AirPodClicker",
            path: "Sources/AirPodClicker",
            linkerSettings: [
                // Embed Info.plist so the bare binary can ask for Bluetooth access
                // (TCC kills processes that touch CoreBluetooth without a usage string).
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist", "-Xlinker", "Resources/Info.plist"])
            ]
        )
    ]
)
