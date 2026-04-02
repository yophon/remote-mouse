import Foundation
import CoreGraphics

// MARK: - Screen Cache

/// Caches the display list to avoid calling CGGetActiveDisplayList on every move event.
/// Refreshes automatically after `ttl` seconds.
class ScreenCache {
    private var screens: [CGRect] = []
    private var lastRefresh: Date = .distantPast
    private let ttl: TimeInterval = 2.0

    func get() -> [CGRect] {
        let now = Date()
        if now.timeIntervalSince(lastRefresh) > ttl || screens.isEmpty {
            var count: UInt32 = 0
            CGGetActiveDisplayList(0, nil, &count)
            var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
            CGGetActiveDisplayList(count, &displays, &count)
            screens = displays.map { CGDisplayBounds($0) }
            lastRefresh = now
        }
        return screens
    }
}

// MARK: - Mouse Controller

struct MouseController {
    static let screenCache = ScreenCache()

    static func move(dx: Double, dy: Double) {
        guard let current = CGEvent(source: nil)?.location else { return }
        let screens = screenCache.get()

        let targetX = current.x + dx
        let targetY = current.y + dy
        let targetPos = CGPoint(x: targetX, y: targetY)

        var finalPos = targetPos
        let isGlobalHit = screens.contains { $0.contains(targetPos) }

        if !isGlobalHit {
            if let currentScreen = screens.first(where: { $0.contains(current) }) {
                let clampedX = min(max(targetX, currentScreen.minX), currentScreen.maxX - 1)
                let clampedY = min(max(targetY, currentScreen.minY), currentScreen.maxY - 1)
                finalPos = CGPoint(x: clampedX, y: clampedY)
            }
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: finalPos,
            mouseButton: .left
        )

        event?.setDoubleValueField(CGEventField.mouseEventDeltaX, value: dx)
        event?.setDoubleValueField(CGEventField.mouseEventDeltaY, value: dy)
        event?.post(tap: CGEventTapLocation.cgSessionEventTap)
    }

    static func click(button: String) {
        guard let pos = CGEvent(source: nil)?.location else { return }
        let source = CGEventSource(stateID: .combinedSessionState)

        let downType: CGEventType
        let upType: CGEventType
        let mouseButton: CGMouseButton

        switch button {
        case "right":
            downType = .rightMouseDown
            upType = .rightMouseUp
            mouseButton = .right
        default:
            downType = .leftMouseDown
            upType = .leftMouseUp
            mouseButton = .left
        }

        let down = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: pos, mouseButton: mouseButton)
        down?.setIntegerValueField(CGEventField.mouseEventClickState, value: 1)
        down?.post(tap: CGEventTapLocation.cgSessionEventTap)

        let up = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: pos, mouseButton: mouseButton)
        up?.setIntegerValueField(CGEventField.mouseEventClickState, value: 1)
        up?.post(tap: CGEventTapLocation.cgSessionEventTap)
    }

    static func doubleClick() {
        guard let pos = CGEvent(source: nil)?.location else { return }
        let source = CGEventSource(stateID: .combinedSessionState)

        let down1 = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left)
        down1?.setIntegerValueField(CGEventField.mouseEventClickState, value: 1)
        down1?.post(tap: CGEventTapLocation.cgSessionEventTap)

        let up1 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left)
        up1?.setIntegerValueField(CGEventField.mouseEventClickState, value: 1)
        up1?.post(tap: CGEventTapLocation.cgSessionEventTap)

        let down2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left)
        down2?.setIntegerValueField(CGEventField.mouseEventClickState, value: 2)
        down2?.post(tap: CGEventTapLocation.cgSessionEventTap)

        let up2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left)
        up2?.setIntegerValueField(CGEventField.mouseEventClickState, value: 2)
        up2?.post(tap: CGEventTapLocation.cgSessionEventTap)
    }

    static func mouseDown(button: String) {
        guard let pos = CGEvent(source: nil)?.location else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let type: CGEventType = (button == "right") ? .rightMouseDown : .leftMouseDown
        let mouseButton: CGMouseButton = (button == "right") ? .right : .left

        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: pos, mouseButton: mouseButton)
        event?.setIntegerValueField(CGEventField.mouseEventClickState, value: 1)
        event?.post(tap: CGEventTapLocation.cgSessionEventTap)
    }

    static func mouseUp(button: String) {
        guard let pos = CGEvent(source: nil)?.location else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let type: CGEventType = (button == "right") ? .rightMouseUp : .leftMouseUp
        let mouseButton: CGMouseButton = (button == "right") ? .right : .left

        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: pos, mouseButton: mouseButton)
        event?.setIntegerValueField(CGEventField.mouseEventClickState, value: 1)
        event?.post(tap: CGEventTapLocation.cgSessionEventTap)
    }

    static func scroll(dx: Double, dy: Double) {
        let scrollY = Int32(dy)
        let scrollX = Int32(dx)
        let source = CGEventSource(stateID: .combinedSessionState)
        if let scrollEvent = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: scrollY,
            wheel2: scrollX,
            wheel3: 0
        ) {
            scrollEvent.post(tap: CGEventTapLocation.cgSessionEventTap)
        }
    }

    static func drag(dx: Double, dy: Double) {
        guard let currentEvent = CGEvent(source: nil) else { return }
        let current = currentEvent.location
        let screens = screenCache.get()

        let targetX = current.x + dx
        let targetY = current.y + dy
        let targetPos = CGPoint(x: targetX, y: targetY)

        var finalPos = targetPos
        if !screens.contains(where: { $0.contains(targetPos) }) {
            if let currentScreen = screens.first(where: { $0.contains(current) }) {
                let clampedX = min(max(targetX, currentScreen.minX), currentScreen.maxX - 1)
                let clampedY = min(max(targetY, currentScreen.minY), currentScreen.maxY - 1)
                finalPos = CGPoint(x: clampedX, y: clampedY)
            }
        }

        let dragEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDragged,
            mouseCursorPosition: finalPos,
            mouseButton: .left
        )

        dragEvent?.setDoubleValueField(CGEventField.mouseEventDeltaX, value: dx)
        dragEvent?.setDoubleValueField(CGEventField.mouseEventDeltaY, value: dy)
        dragEvent?.post(tap: CGEventTapLocation.cgSessionEventTap)
    }
}
