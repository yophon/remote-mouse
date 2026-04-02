import Foundation
import CoreGraphics
import Carbon.HIToolbox

// MARK: - Keyboard Controller

struct KeyboardController {

    // Special key name → macOS virtual keycode
    private static let specialKeys: [String: CGKeyCode] = [
        "enter":       CGKeyCode(kVK_Return),
        "return":      CGKeyCode(kVK_Return),
        "tab":         CGKeyCode(kVK_Tab),
        "escape":      CGKeyCode(kVK_Escape),
        "esc":         CGKeyCode(kVK_Escape),
        "backspace":   CGKeyCode(kVK_Delete),
        "delete":      CGKeyCode(kVK_ForwardDelete),
        "space":       CGKeyCode(kVK_Space),
        "up":          CGKeyCode(kVK_UpArrow),
        "down":        CGKeyCode(kVK_DownArrow),
        "left":        CGKeyCode(kVK_LeftArrow),
        "right":       CGKeyCode(kVK_RightArrow),
        "home":        CGKeyCode(kVK_Home),
        "end":         CGKeyCode(kVK_End),
        "pageup":      CGKeyCode(kVK_PageUp),
        "pagedown":    CGKeyCode(kVK_PageDown),
        "f1":          CGKeyCode(kVK_F1),
        "f2":          CGKeyCode(kVK_F2),
        "f3":          CGKeyCode(kVK_F3),
        "f4":          CGKeyCode(kVK_F4),
        "f5":          CGKeyCode(kVK_F5),
        "f6":          CGKeyCode(kVK_F6),
        "f7":          CGKeyCode(kVK_F7),
        "f8":          CGKeyCode(kVK_F8),
        "f9":          CGKeyCode(kVK_F9),
        "f10":         CGKeyCode(kVK_F10),
        "f11":         CGKeyCode(kVK_F11),
        "f12":         CGKeyCode(kVK_F12),
        "volumeup":    CGKeyCode(kVK_VolumeUp),
        "volumedown":  CGKeyCode(kVK_VolumeDown),
        "mute":        CGKeyCode(kVK_Mute),
    ]

    /// Type a string of text using CGEvent key simulation.
    /// Each character is typed via its Unicode scalar.
    static func typeText(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for char in text {
            // Check if it's a single-char that maps to a special key
            // (unlikely for typeText, but just in case)
            let scalars = Array(char.unicodeScalars)
            guard !scalars.isEmpty else { continue }

            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            var utf16 = Array(char.utf16)
            down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            up?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

            down?.post(tap: .cgSessionEventTap)
            up?.post(tap: .cgSessionEventTap)
        }
    }

    /// Press a special key by name (e.g. "enter", "backspace", "up").
    /// Supports optional modifiers.
    static func pressSpecialKey(_ keyName: String, modifiers: [String] = []) {
        let lower = keyName.lowercased()
        guard let keyCode = specialKeys[lower] else {
            // Not a recognized special key — try typing it as text
            typeText(keyName)
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "shift":   flags.insert(.maskShift)
            case "control", "ctrl": flags.insert(.maskControl)
            case "alt", "option":   flags.insert(.maskAlternate)
            case "command", "cmd", "meta": flags.insert(.maskCommand)
            default: break
            }
        }

        if !flags.isEmpty {
            down?.flags = flags
            up?.flags = []
        }

        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
