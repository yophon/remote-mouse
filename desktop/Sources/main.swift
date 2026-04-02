import Foundation
import Network

// MARK: - Configuration

let wsPort: UInt16 = 9876
let udpPort: UInt16 = 9877
let bonjourServiceType = "_remotemouse._tcp."

// MARK: - Start

print("Remote Mouse Server starting...")
print("  WebSocket: \(wsPort)")
print("  UDP:       \(udpPort)")
print("  Max WS connections: 2")

let wsServer = WebSocketServer(port: wsPort, maxConnections: 2, bonjourType: bonjourServiceType)
wsServer.start()

let udpServer = UDPServer(port: udpPort)
udpServer.start()

dispatchMain()
