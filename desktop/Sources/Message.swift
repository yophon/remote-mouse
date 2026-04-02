import Foundation

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

// MARK: - Binary Protocol
//
// For high-frequency messages (move, drag, scroll), a compact binary
// format is supported alongside JSON. Layout (little-endian):
//
//   Byte 0:    type tag  (1 = move, 2 = drag, 3 = scroll)
//   Byte 1-4:  dx        (Float32)
//   Byte 5-8:  dy        (Float32)
//   Byte 9-12: id        (Int32)
//   Total: 13 bytes
//
// All other message types continue to use JSON.

// MARK: - Message Model

struct Message {
    let type: String
    let dx: Double
    let dy: Double
    let button: String
    let id: Int?
    let key: String
    let modifiers: [String]

    private init(type: String, dx: Double = 0, dy: Double = 0, button: String = "left",
                 id: Int? = nil, key: String = "", modifiers: [String] = []) {
        self.type = type
        self.dx = dx
        self.dy = dy
        self.button = button
        self.id = id
        self.key = key
        self.modifiers = modifiers
    }

    /// Try parsing binary format first, then JSON.
    init?(from data: Data) {
        if let msg = Message.fromBinary(data) {
            self = msg
            return
        }
        if let msg = Message.fromJSON(data) {
            self = msg
            return
        }
        return nil
    }

    private static func fromBinary(_ data: Data) -> Message? {
        guard data.count == 13 else { return nil }

        let tag = data[data.startIndex]
        let type: String
        switch tag {
        case 1: type = "move"
        case 2: type = "drag"
        case 3: type = "scroll"
        default: return nil
        }

        let dx = data.withUnsafeBytes { ptr -> Float32 in
            ptr.loadUnaligned(fromByteOffset: 1, as: Float32.self)
        }
        let dy = data.withUnsafeBytes { ptr -> Float32 in
            ptr.loadUnaligned(fromByteOffset: 5, as: Float32.self)
        }
        let id = data.withUnsafeBytes { ptr -> Int32 in
            ptr.loadUnaligned(fromByteOffset: 9, as: Int32.self)
        }

        return Message(
            type: type,
            dx: Double(dx),
            dy: Double(dy),
            id: Int(id)
        )
    }

    private static func fromJSON(_ data: Data) -> Message? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }
        let mods = json["modifiers"] as? [String] ?? []
        return Message(
            type: type,
            dx: json["dx"] as? Double ?? 0,
            dy: json["dy"] as? Double ?? 0,
            button: json["button"] as? String ?? "left",
            id: json["id"] as? Int,
            key: json["key"] as? String ?? "",
            modifiers: mods
        )
    }
}

// MARK: - Dispatch (with dedup)

let dedup = Deduplicator()

func dispatchMessage(_ msg: Message) {
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
    case "keyText":
        if !msg.key.isEmpty {
            KeyboardController.typeText(msg.key)
        }
    case "keySpecial":
        if !msg.key.isEmpty {
            KeyboardController.pressSpecialKey(msg.key, modifiers: msg.modifiers)
        }
    case "ping":
        break
    default:
        break
    }
}
