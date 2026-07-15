import Foundation
import Network

enum NetworkMode {
    case idle
    case host
    case client
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

enum NetworkEvent {
    case playerConnected(PlayerInfo)
    case playerDisconnected(PlayerInfo)
    case message(GameMessage)
}

private final class PeerConnection {
    let id: UUID
    let connection: NWConnection
    var buffer = Data()
    var playerInfo: PlayerInfo?

    init(id: UUID = UUID(), connection: NWConnection) {
        self.id = id
        self.connection = connection
    }
}

@MainActor
final class NetworkManager: ObservableObject {
    @Published private(set) var mode: NetworkMode = .idle
    @Published private(set) var status: ConnectionStatus = .disconnected

    var onEvent: ((NetworkEvent) -> Void)?

    private var listener: NWListener?
    private var peers: [UUID: PeerConnection] = [:]
    private var clientPeer: PeerConnection?
    private var listenerPort: UInt16 = 5000

    private var lastHostIP: String?
    private var lastHostPort: UInt16 = 5000
    private var reconnectTask: Task<Void, Never>?
    private var hostRestartTask: Task<Void, Never>?

    private let queue = DispatchQueue(label: "quizIOS2.network", qos: .userInitiated)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func startServer(port: UInt16 = 5000, serviceName: String? = "YaZnayu") async {
        stopAll()
        mode = .host
        status = .connecting
        listenerPort = port

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let nwPort = NWEndpoint.Port(rawValue: port) ?? 5000
            let listener = try NWListener(using: parameters, on: nwPort)
            self.listener = listener

            if let serviceName {
                listener.service = NWListener.Service(name: serviceName, type: "_yaznayu._tcp", domain: nil, txtRecord: nil)
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self.status = .connected
                    case .failed(let error):
                        self.status = .failed(error.localizedDescription)
                        self.scheduleHostRestart()
                    case .cancelled:
                        if self.mode == .idle {
                            self.status = .disconnected
                        }
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task { @MainActor in
                    self.acceptNewPeer(connection)
                }
            }

            listener.start(queue: queue)
        } catch {
            status = .failed(error.localizedDescription)
            scheduleHostRestart()
        }
    }

    func connectToHost(ip: String, port: UInt16 = 5000) async {
        stopClientOnly()
        mode = .client
        status = .connecting

        lastHostIP = ip
        lastHostPort = port

        guard let host = NWEndpoint.Host(ip), let nwPort = NWEndpoint.Port(rawValue: port) else {
            status = .failed("Неверный IP или порт")
            scheduleClientReconnect()
            return
        }

        let connection = NWConnection(host: host, port: nwPort, using: .tcp)
        let peer = PeerConnection(connection: connection)
        clientPeer = peer

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .ready:
                    self.status = .connected
                    self.startReceiveLoop(for: peer, isClient: true)
                case .failed(let error):
                    self.status = .failed(error.localizedDescription)
                    self.scheduleClientReconnect()
                case .cancelled:
                    if self.mode == .idle {
                        self.status = .disconnected
                    } else {
                        self.scheduleClientReconnect()
                    }
                default:
                    break
                }
            }
        }

        connection.start(queue: queue)
    }

    func stopAll() {
        hostRestartTask?.cancel()
        reconnectTask?.cancel()

        listener?.cancel()
        listener = nil

        for (_, peer) in peers {
            peer.connection.cancel()
        }
        peers.removeAll()

        clientPeer?.connection.cancel()
        clientPeer = nil

        mode = .idle
        status = .disconnected
    }

    func send(_ message: GameMessage, to peerID: UUID? = nil) async {
        do {
            let data = try encoder.encode(message)
            var framed = data
            framed.append(0x0A) // newline-delimited JSON

            if mode == .host {
                if let peerID, let peer = peers[peerID] {
                    try await sendRaw(framed, over: peer.connection)
                } else {
                    for (_, peer) in peers {
                        try await sendRaw(framed, over: peer.connection)
                    }
                }
            } else if mode == .client, let clientPeer {
                try await sendRaw(framed, over: clientPeer.connection)
            }
        } catch {
            status = .failed(error.localizedDescription)
            if mode == .client {
                scheduleClientReconnect()
            }
        }
    }

    private func acceptNewPeer(_ connection: NWConnection) {
        let peer = PeerConnection(connection: connection)
        peers[peer.id] = peer

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .ready:
                    self.startReceiveLoop(for: peer, isClient: false)
                case .failed, .cancelled:
                    self.removePeer(peer.id)
                default:
                    break
                }
            }
        }

        connection.start(queue: queue)
    }

    private func removePeer(_ peerID: UUID) {
        guard let peer = peers.removeValue(forKey: peerID) else { return }
        peer.connection.cancel()

        if let player = peer.playerInfo {
            onEvent?(.playerDisconnected(player))
        }
    }

    private func startReceiveLoop(for peer: PeerConnection, isClient: Bool) {
        receiveNextChunk(for: peer, isClient: isClient)
    }

    private func receiveNextChunk(for peer: PeerConnection, isClient: Bool) {
        peer.connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.status = .failed(error.localizedDescription)
                    if isClient {
                        self.scheduleClientReconnect()
                    } else {
                        self.removePeer(peer.id)
                    }
                    return
                }

                if let data, !data.isEmpty {
                    peer.buffer.append(data)
                    self.parseBufferedMessages(for: peer)
                }

                if isComplete {
                    if isClient {
                        self.scheduleClientReconnect()
                    } else {
                        self.removePeer(peer.id)
                    }
                    return
                }

                self.receiveNextChunk(for: peer, isClient: isClient)
            }
        }
    }

    private func parseBufferedMessages(for peer: PeerConnection) {
        while let newlineIndex = peer.buffer.firstIndex(of: 0x0A) {
            let messageData = peer.buffer.prefix(upTo: newlineIndex)
            peer.buffer.removeSubrange(...newlineIndex)

            guard !messageData.isEmpty else { continue }

            do {
                let msg = try decoder.decode(GameMessage.self, from: messageData)
                if msg.kind == .hello, let player = msg.player {
                    peer.playerInfo = player
                    onEvent?(.playerConnected(player))
                }
                onEvent?(.message(msg))
            } catch {
                onEvent?(.message(GameMessage(kind: .error, senderID: UUID(), text: "Ошибка декодирования: \(error.localizedDescription)")))
            }
        }
    }

    private func sendRaw(_ data: Data, over connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func stopClientOnly() {
        clientPeer?.connection.cancel()
        clientPeer = nil
    }

    private func scheduleClientReconnect() {
        reconnectTask?.cancel()
        guard mode == .client, let ip = lastHostIP else { return }

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            await self.connectToHost(ip: ip, port: self.lastHostPort)
        }
    }

    private func scheduleHostRestart() {
        hostRestartTask?.cancel()
        guard mode == .host else { return }

        hostRestartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            await self.startServer(port: self.listenerPort)
        }
    }
}
