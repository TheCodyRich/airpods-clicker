import ApplicationServices
import Foundation

enum SlideAction: String, CaseIterable {
    case next, previous, none

    var title: String {
        switch self {
        case .next: return "Next slide (→)"
        case .previous: return "Previous slide (←)"
        case .none: return "Do nothing"
        }
    }

    /// macOS virtual key codes for the arrow keys Google Slides listens to.
    var keyCode: CGKeyCode? {
        switch self {
        case .next: return 124
        case .previous: return 123
        case .none: return nil
        }
    }
}

enum Keys {
    /// Posting synthetic key events needs Accessibility access.
    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func perform(_ action: SlideAction) {
        guard let code = action.keyCode else { return }
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
