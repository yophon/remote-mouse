import Foundation
import Network

// MARK: - WebSocket Server

class WebSocketServer {
    let port: UInt16
    let maxConnections: Int
    let bonjourType: String?
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    init(port: UInt16, maxConnections: Int = 2, bonjourType: String? = nil) {
        self.port = port
        self.maxConnections = maxConnections
        self.bonjourType = bonjourType
    }

    func start() {
        let params = NWParameters(tls: nil)
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[WS] Failed to create listener on port \(port): \(error)")
            return
        }

        if let bonjourType = bonjourType {
            listener!.service = NWListener.Service(type: bonjourType)
        }

        listener!.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[WS] Listening on port \(self.port)")
                if self.bonjourType != nil {
                    print("[Bonjour] Advertising on port \(self.port)")
                }
            case .failed(let err):
                print("[WS] Listener failed: \(err)")
            default:
                break
            }
        }

        listener!.newConnectionHandler = { [weak self] conn in
            self?.handleNewConnection(conn)
        }

        listener!.start(queue: .main)
    }

    private func handleNewConnection(_ conn: NWConnection) {
        if connections.count >= maxConnections {
            print("[WS] Rejected connection (limit \(maxConnections) reached)")
            conn.cancel()
            return
        }

        connections.append(conn)
        print("[WS] New connection (\(connections.count)/\(maxConnections))")

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.receiveLoop(conn)
            case .failed, .cancelled:
                self.removeConnection(conn)
            default:
                break
            }
        }

        conn.start(queue: .main)
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receiveMessage { data, context, _, error in
            if let error = error {
                print("[WS] Receive error: \(error)")
                self.removeConnection(conn)
                return
            }

            if let data = data, !data.isEmpty,
               let msg = Message(from: data) {
                dispatchMessage(msg)
            }

            // Continue receiving
            self.receiveLoop(conn)
        }
    }

    private func removeConnection(_ conn: NWConnection) {
        connections.removeAll { $0 === conn }
        print("[WS] Connection closed (\(connections.count)/\(maxConnections))")
    }
}
