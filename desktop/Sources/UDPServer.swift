import Foundation
import Network

// MARK: - UDP Server

class UDPServer {
    let port: UInt16
    private var listener: NWListener?

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[UDP] Failed to create listener on port \(port): \(error)")
            return
        }

        listener!.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[UDP] Listening on port \(self.port)")
            case .failed(let err):
                print("[UDP] Listener failed: \(err)")
            default:
                break
            }
        }

        listener!.newConnectionHandler = { conn in
            conn.stateUpdateHandler = { state in
                if case .ready = state {
                    self.receiveLoop(conn)
                }
            }
            conn.start(queue: .main)
        }

        listener!.start(queue: .main)
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receiveMessage { data, _, _, error in
            if let data = data, !data.isEmpty,
               let msg = Message(from: data) {
                dispatchMessage(msg)
            }

            if error == nil {
                self.receiveLoop(conn)
            }
        }
    }
}
