import AppKit
import Foundation

// Usage:
//   AirPodClicker            menu bar app (default)
//   AirPodClicker --scan     print every AirPods advertisement nearby (debugging)
//   AirPodClicker --watch    print lid events and press keys, no menu bar

let args = CommandLine.arguments

func stamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f.string(from: Date())
}

func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }

if args.contains("--scan") {
    setvbuf(stdout, nil, _IOLBF, 0)
    let scanner = LidScanner()
    scanner.onStateChange = { print("[\(stamp())] \($0)") }
    scanner.onPacket = { p in
        print("[\(stamp())] \(p.modelName.padding(toLength: 22, withPad: " ", startingAt: 0)) "
              + "rssi \(p.rssi)  lid \(String(format: "0x%02X", p.lidByte)) "
              + "(\(p.lidClosed ? "closed" : "open  "), count \(p.lidCounter))  \(hex(p.raw))")
    }
    scanner.start()
    print("Scanning for AirPods advertisements. Open and close your case near the Mac. Ctrl-C to stop.")
    RunLoop.main.run()
}

if args.contains("--watch") {
    setvbuf(stdout, nil, _IOLBF, 0)
    let prefs = Prefs()
    let scanner = LidScanner()
    scanner.settings = prefs.scannerSettings
    scanner.onStateChange = { print("[\(stamp())] \($0)") }
    let clicker = Clicker(prefs: prefs)
    scanner.onEvent = { event, p in
        let action = clicker.fire(event)
        print("[\(stamp())] lid \(event.rawValue) (\(p.modelName), rssi \(p.rssi)) -> \(action?.rawValue ?? "debounced")")
    }
    if !Keys.ensureAccessibility(prompt: true) {
        print("Accessibility access is needed to press keys. Grant it in System Settings, then rerun.")
    }
    scanner.start()
    RunLoop.main.run()
}

let app = NSApplication.shared
let delegate = MenuBarController()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
