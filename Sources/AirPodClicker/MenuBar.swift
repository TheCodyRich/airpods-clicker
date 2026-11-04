import AppKit
import Foundation

/// User settings, persisted in UserDefaults.
final class Prefs {
    private let d = UserDefaults.standard

    var enabled: Bool {
        get { d.object(forKey: "enabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "enabled") }
    }
    var onOpen: SlideAction {
        get { SlideAction(rawValue: d.string(forKey: "onOpen") ?? "") ?? .next }
        set { d.set(newValue.rawValue, forKey: "onOpen") }
    }
    var onClose: SlideAction {
        get { SlideAction(rawValue: d.string(forKey: "onClose") ?? "") ?? .none }
        set { d.set(newValue.rawValue, forKey: "onClose") }
    }
    var minRSSI: Int {
        get { d.object(forKey: "minRSSI") as? Int ?? -65 }
        set { d.set(newValue, forKey: "minRSSI") }
    }

    var scannerSettings: ScannerSettings {
        ScannerSettings(minRSSI: minRSSI)
    }
}

/// Maps lid events to key presses, with a debounce so one flip is one click.
final class Clicker {
    private let prefs: Prefs
    private var lastFired = Date.distantPast
    private let debounce: TimeInterval = 0.8

    init(prefs: Prefs) { self.prefs = prefs }

    @discardableResult
    func fire(_ event: LidEvent) -> SlideAction? {
        guard prefs.enabled else { return SlideAction.none }
        let action = event == .opened ? prefs.onOpen : prefs.onClose
        guard action != .none else { return SlideAction.none }
        guard Date().timeIntervalSince(lastFired) >= debounce else { return nil }
        lastFired = Date()
        Keys.perform(action)
        return action
    }
}

final class MenuBarController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let prefs = Prefs()
    private let scanner = LidScanner()
    private lazy var clicker = Clicker(prefs: prefs)
    private var statusItem: NSStatusItem!
    private var bluetoothState = "Starting…"
    private var lastEvent = "No lid events yet"

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        scanner.settings = prefs.scannerSettings
        scanner.onStateChange = { [weak self] in self?.bluetoothState = $0 }
        scanner.onEvent = { [weak self] event, packet in
            guard let self else { return }
            let action = self.clicker.fire(event)
            let f = DateFormatter()
            f.timeStyle = .medium
            self.lastEvent = "Lid \(event.rawValue) at \(f.string(from: Date()))"
                + (action.map { $0 == .none ? "" : " → \($0.rawValue)" } ?? "")
            self.flash()
        }
        scanner.start()

        Keys.ensureAccessibility(prompt: true)
    }

    // Rebuild on open so status lines are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(disabled("AirPod Clicker — \(bluetoothState)"))
        if let p = scanner.lastPacket {
            menu.addItem(disabled("\(p.modelName): lid \(p.lidClosed ? "closed" : "open"), signal \(p.rssi) dBm"))
        } else {
            menu.addItem(disabled("No AirPods seen yet"))
        }
        menu.addItem(disabled(lastEvent))
        if !Keys.ensureAccessibility(prompt: false) {
            menu.addItem(item("⚠︎ Grant Accessibility access…", #selector(openAccessibility)))
        }
        menu.addItem(.separator())

        let toggle = item("Enabled", #selector(toggleEnabled))
        toggle.state = prefs.enabled ? .on : .off
        menu.addItem(toggle)

        menu.addItem(actionSubmenu("When lid opens", current: prefs.onOpen, selector: #selector(setOpenAction(_:))))
        menu.addItem(actionSubmenu("When lid closes", current: prefs.onClose, selector: #selector(setCloseAction(_:))))

        let range = NSMenuItem(title: "Range", action: nil, keyEquivalent: "")
        let rangeMenu = NSMenu()
        for (title, value) in [("Close (hand near Mac)", -50), ("Normal (same desk)", -65), ("Far (across the room)", -85)] {
            let i = item(title, #selector(setRange(_:)))
            i.tag = value
            i.state = prefs.minRSSI == value ? .on : .off
            rangeMenu.addItem(i)
        }
        range.submenu = rangeMenu
        menu.addItem(range)

        menu.addItem(.separator())
        menu.addItem(item("Quit", #selector(quit), key: "q"))
    }

    private func actionSubmenu(_ title: String, current: SlideAction, selector: Selector) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for action in SlideAction.allCases {
            let i = item(action.title, selector)
            i.representedObject = action.rawValue
            i.state = action == current ? .on : .off
            sub.addItem(i)
        }
        parent.submenu = sub
        return parent
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    private func updateIcon(highlight: Bool = false) {
        let name = highlight ? "airpodspro.chargingcase.wireless.fill" : "airpodspro.chargingcase.wireless"
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: "AirPod Clicker") {
            img.isTemplate = true
            statusItem.button?.image = img
            statusItem.button?.title = ""
        } else {
            statusItem.button?.title = highlight ? "●" : "◎"
        }
        statusItem.button?.appearsDisabled = !prefs.enabled
    }

    private func flash() {
        updateIcon(highlight: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.updateIcon() }
    }

    @objc private func toggleEnabled() { prefs.enabled.toggle(); updateIcon() }
    @objc private func setRange(_ sender: NSMenuItem) { prefs.minRSSI = sender.tag; scanner.settings = prefs.scannerSettings }
    @objc private func setOpenAction(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let a = SlideAction(rawValue: raw) { prefs.onOpen = a }
    }
    @objc private func setCloseAction(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let a = SlideAction(rawValue: raw) { prefs.onClose = a }
    }
    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
