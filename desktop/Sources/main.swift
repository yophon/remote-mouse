import Foundation
import Network

// MARK: - Configuration

let wsPort: UInt16 = 9876
let udpPort: UInt16 = 9877
let bonjourServiceType = "_remotemouse._tcp."

// MARK: - Bonjour Advertisement

func publishBonjourService() {
    let listener = try! NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: wsPort)!)
    listener.service = NWListener.Service(type: bonjourServiceType)
    listener.stateUpdateHandler = { state in
        if case .ready = state {
            print("[Bonjour] Advertising '\(bonjourServiceType)' on port \(wsPort)")
        }
    }
    listener.newConnectionHandler = { $0.cancel() }
    listener.start(queue: .main)
}

// MARK: - Start

print("Remote Mouse Server starting...")
print("  WebSocket: \(wsPort)")
print("  UDP:       \(udpPort)")
print("  Max WS connections: 2")

let wsServer = WebSocketServer(port: wsPort, maxConnections: 2)
wsServer.start()

let udpServer = UDPServer(port: udpPort)
udpServer.start()

publishBonjourService()

dispatchMain()
