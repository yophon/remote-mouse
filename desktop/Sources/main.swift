import Foundation
import Network
import CoreGraphics

// MARK: - Configuration

let wsPort: UInt16 = 9876
let udpPort: UInt16 = 9877
let serviceName = "RemoteMouse"

// MARK: - Message Deduplication

class Deduplicator {
    private var seen = Set<Int>()
    private var queue = [Int]()
    private let capacity = 512

    /// Returns true if this id is new (should be processed).
    func tryAccept(_ id: Int) -> Bool {
        if seen.contains(id) { return false }
        seen.insert(id)
        queue.append(id)
        if queue.count > capacity {
            let old = queue.removeFirst()
            seen.remove(old)
        }
        return true
    }
}

let dedup = Deduplicator()

// MARK: - Mouse Controller

struct MouseController {
    static func getVisibleScreens() -> [CGRect] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return displays.map { CGDisplayBounds($0) }
    }

    static func move(dx: Double, dy: Double) {
        guard let current = CGEvent(source: nil)?.location else { return }
        let screens = getVisibleScreens()
        
        let targetX = current.x + dx
        let targetY = current.y + dy
        let targetPos = CGPoint(x: targetX, y: targetY)
        
        // Find if target is inside any screen
        var finalPos = targetPos
        let isGlobalHit = screens.contains { $0.contains(targetPos) }
        
        if !isGlobalHit {
            // It's a wall hit! Find the screen we are currently in and clamp to it.
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
        let screens = getVisibleScreens()
        
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

// MARK: - JSON Message Parsing

struct Message {
    let type: String
    let dx: Double
    let dy: Double
    let button: String
    let id: Int?

    init?(from data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }
        self.type = type
        self.dx = json["dx"] as? Double ?? 0
        self.dy = json["dy"] as? Double ?? 0
        self.button = json["button"] as? String ?? "left"
        self.id = json["id"] as? Int
    }
}

// MARK: - Dispatch message (with dedup)

func dispatchMessage(_ msg: Message) {
    // Deduplicate by id if present
    if let id = msg.id {
        if !dedup.tryAccept(id) { return }
    }

    switch msg.type {
    case "move":
        MouseController.move(dx: msg.dx, dy: msg.dy)
    case "click":
        MouseController.click(button: msg.button)
    case "mouseDown":
        MouseController.mouseDown(button: msg.button)
    case "mouseUp":
        MouseController.mouseUp(button: msg.button)
    case "doubleClick":
        MouseController.doubleClick()
    case "scroll":
        MouseController.scroll(dx: msg.dx, dy: msg.dy)
    case "drag":
        MouseController.drag(dx: msg.dx, dy: msg.dy)
    case "ping":
        break
    default:
        break
    }
}

// MARK: - UDP Listener

class UDPServer {
    let listener: NWListener

    init(port: UInt16) {
        let params = NWParameters.udp
        listener = try! NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("✓ UDP listening on port \(udpPort)")
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: .main)
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        receiveData(on: connection)
    }

    private func receiveData(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, _, _, error in
            if error != nil { return }
            if let data = content, let msg = Message(from: data) {
                dispatchMessage(msg)
            }
            self?.receiveData(on: connection)
        }
    }
}

// MARK: - WebSocket Server

class WebSocketServer {
    let listener: NWListener
    let bonjourService: NetService
    var connections: [NWConnection] = []

    init(port: UInt16) {
        let params = NWParameters(tls: nil)
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        listener = try! NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        bonjourService = NetService(
            domain: "local.",
            type: "_remotemouse._tcp.",
            name: serviceName,
            port: Int32(port)
        )
    }

    func start() {
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✓ WebSocket listening on port \(wsPort)")
            case .failed(let error):
                print("✗ WebSocket server failed: \(error)")
                exit(1)
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: .main)
        bonjourService.publish()
        print("✓ Bonjour published: \(serviceName)._remotemouse._tcp.local.")
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        print("+ Client connected: \(connection.endpoint)")

        connection.stateUpdateHandler = { [weak self] state in
            if case .failed(_) = state { self?.removeConnection(connection) }
            if case .cancelled = state { self?.removeConnection(connection) }
        }

        connection.start(queue: .main)
        receiveMessage(on: connection)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, _, _, error in
            if let error = error {
                print("- Receive error: \(error)")
                self?.removeConnection(connection)
                return
            }

            if let data = content, let msg = Message(from: data) {
                dispatchMessage(msg)
            }

            self?.receiveMessage(on: connection)
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        connection.cancel()
        print("- Client disconnected")
    }
}

// MARK: - Main

print("╔══════════════════════════════════════╗")
print("║       Remote Mouse Server            ║")
print("║  WebSocket: \(wsPort)  |  UDP: \(udpPort)        ║")
print("╚══════════════════════════════════════╝")
print("")

let trusted = CGPreflightPostEventAccess()
if !trusted {
    print("⚠ Accessibility permission required!")
    print("  System Settings → Privacy & Security → Accessibility")
    print("  Requesting permission now...")
    CGRequestPostEventAccess()
}

let wsServer = WebSocketServer(port: wsPort)
let udpServer = UDPServer(port: udpPort)
wsServer.start()
udpServer.start()

print("  Waiting for connections...")

RunLoop.main.run()
