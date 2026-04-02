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

    /// Press a key by name with optional modifiers.
    /// Recognized names (enter, backspace, up, etc.) use virtual keycodes.
    /// Single characters use Unicode-based key events with modifier flags.
    static func pressSpecialKey(_ keyName: String, modifiers: [String] = []) {
        let lower = keyName.lowercased()

        let flags = buildFlags(modifiers)
        let source = CGEventSource(stateID: .combinedSessionState)

        if let keyCode = specialKeys[lower] {
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

            if !flags.isEmpty {
                down?.flags = flags
                up?.flags = []
            }

            down?.post(tap: .cgSessionEventTap)
            up?.post(tap: .cgSessionEventTap)
        } else {
            // Regular character with modifiers (e.g. Cmd+C)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            var utf16 = Array(keyName.utf16)
            down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            up?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

            if !flags.isEmpty {
                down?.flags = flags
                up?.flags = []
            }

            down?.post(tap: .cgSessionEventTap)
            up?.post(tap: .cgSessionEventTap)
        }
    }

    private static func buildFlags(_ modifiers: [String]) -> CGEventFlags {
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
        return flags
    }
}
