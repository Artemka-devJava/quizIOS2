import Foundation
import Combine
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

struct DiscoveredServer: Identifiable, Equatable {
    let id: String
    let name: String
    let details: String
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

/// Небольшой помощник, чтобы гарантированно вызвать continuation ровно один раз,
/// даже если stateUpdateHandler по какой-то причине сработает повторно
/// до того, как мы успели отписаться.
private final class SingleResumeGuard<T> {
    private var isResumed = false
    private let continuation: CheckedContinuation<T, Never>

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        guard !isResumed else { return }
        isResumed = true
        continuation.resume(returning: value)
    }
}

@MainActor
final class NetworkManager: ObservableObject {
    static let defaultPort: UInt16 = 5000
    static let serviceType = "_yaznayu._tcp"

    @Published private(set) var mode: NetworkMode = .idle
    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var discoveredServers: [DiscoveredServer] = []

    var onEvent: ((NetworkEvent) -> Void)?

    private var listener: NWListener?
    private var browser: NWBrowser?

    private var peers: [UUID: PeerConnection] = [:]
    private var clientPeer: PeerConnection?
    private var discoveredEndpoints: [String: NWEndpoint] = [:]

    private var currentServerPort: UInt16 = NetworkManager.defaultPort
    private var currentServiceName = "Host"

    private var lastHostIP: String?
    private var lastHostPort: UInt16 = NetworkManager.defaultPort
    private var lastEndpoint: NWEndpoint?

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

    /// Запускает TCP-сервер и Bonjour-публикацию сервиса.
    /// Возвращает `true`, только если listener реально перешёл в состояние `.ready`.
    /// До этого момента UI не должен считать сервер запущенным.
    @discardableResult
    func startServer(port: UInt16 = NetworkManager.defaultPort, serviceName: String) async -> Bool {
        stopAll()
        mode = .host
        status = .connecting

        currentServerPort = port
        let trimmedName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        currentServiceName = trimmedName.isEmpty ? "Host" : trimmedName

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            status = .failed("Неверный порт: \(port)")
            mode = .idle
            return false
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: nwPort)
        } catch {
            status = .failed("Не удалось создать сервер: \(error.localizedDescription)")
            mode = .idle
            scheduleHostRestart()
            return false
        }

        self.listener = listener

        listener.service = NWListener.Service(
            name: currentServiceName,
            type: NetworkManager.serviceType,
            domain: nil,
            txtRecord: nil
        )

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task { @MainActor in
                self.acceptNewPeer(connection)
            }
        }

        // Ждём реального результата запуска (ready/failed), а не просто факта вызова start().
        let started = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let resumeGuard = SingleResumeGuard(continuation)

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self.status = .connected
                        resumeGuard.resume(true)

                    case .failed(let error):
                        self.status = .failed("Сервер: \(error.localizedDescription)")
                        self.mode = .idle
                        self.listener?.cancel()
                        self.listener = nil
                        resumeGuard.resume(false)
                        self.scheduleHostRestart()

                    case .cancelled:
                        if self.mode == .idle {
                            self.status = .disconnected
                        }
                        resumeGuard.resume(false)

                    case .waiting(let error):
                        // Порт занят, нет прав и т.п. — тоже считаем это неудачей запуска,
                        // не оставляем UI бесконечно висеть в "Запуск...".
                        self.status = .failed("Сервер ожидает: \(error.localizedDescription)")
                        resumeGuard.resume(false)

                    default:
                        break
                    }
                }
            }

            listener.start(queue: queue)
        }

        return started
    }

    func startBrowsingServers() {
        stopBrowsingServers()

        let parameters = NWParameters.tcp
        let browser = NWBrowser(for: .bonjour(type: NetworkManager.serviceType, domain: nil), using: parameters)
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .failed(let error):
                    self.status = .failed("Поиск серверов: \(error.localizedDescription)")
                case .ready:
                    if self.mode != .host && self.status == .disconnected {
                        self.status = .connecting
                    }
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateDiscoveredServers(with: results)
            }
        }

        browser.start(queue: queue)
    }

    func stopBrowsingServers() {
        browser?.cancel()
        browser = nil
        discoveredServers = []
        discoveredEndpoints = [:]
    }

    func connectToDiscoveredServer(id: String) async {
        guard let endpoint = discoveredEndpoints[id] else {
            status = .failed("Выбранный сервер недоступен")
            startBrowsingServers()
            return
        }
        await connectToEndpoint(endpoint)
    }

    func connectToHost(ip: String, port: UInt16 = NetworkManager.defaultPort) async {
        // Fallback для ручного подключения при необходимости.
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty, let nwPort = NWEndpoint.Port(rawValue: port) else {
            status = .failed("Неверный IP или порт")
            scheduleClientReconnect()
            return
        }

        let host = NWEndpoint.Host(trimmedIP)
        let endpoint = NWEndpoint.hostPort(host: host, port: nwPort)
        lastHostIP = trimmedIP
        lastHostPort = port
        await connectToEndpoint(endpoint)
    }

    func stopAll() {
        hostRestartTask?.cancel()
        reconnectTask?.cancel()

        stopBrowsingServers()

        listener?.cancel()
        listener = nil

        for (_, peer) in peers {
            peer.connection.cancel()
        }
        peers.removeAll()

        clientPeer?.connection.cancel()
        clientPeer = nil

        lastEndpoint = nil
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

    private func connectToEndpoint(_ endpoint: NWEndpoint) async {
        stopClientOnly()
        mode = .client
        status = .connecting
        lastEndpoint = endpoint

        let connection = NWConnection(to: endpoint, using: .tcp)
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
                    self.status = .failed("Клиент: \(error.localizedDescription)")
                    self.scheduleClientReconnect()
                case .waiting(let error):
                    self.status = .failed("Клиент ожидает: \(error.localizedDescription)")
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

    private func updateDiscoveredServers(with results: Set<NWBrowser.Result>) {
        var endpointsByID: [String: NWEndpoint] = [:]
        var items: [DiscoveredServer] = []

        for result in results {
            let endpoint = result.endpoint
            let id = endpointID(endpoint)
            let name = endpointName(endpoint)
            let details = endpointDetails(endpoint)

            endpointsByID[id] = endpoint
            items.append(DiscoveredServer(id: id, name: name, details: details))
        }

        discoveredEndpoints = endpointsByID
        discoveredServers = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if mode != .host && status == .connecting && !discoveredServers.isEmpty {
            status = .disconnected
        }
    }

    private func endpointID(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .service(let name, let type, let domain, _):
            return "\(name)|\(type)|\(domain)"
        case .hostPort(let host, let port):
            return "\(host):\(port.rawValue)"
        default:
            return endpoint.debugDescription
        }
    }

    private func endpointName(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        case .hostPort(let host, let port):
            return "\(host):\(port.rawValue)"
        default:
            return "Локальный сервер"
        }
    }

    private func endpointDetails(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .service:
            return ""
        case .hostPort(_, let port):
            return "Порт \(port.rawValue)"
        default:
            return ""
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
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
        guard mode == .client else { return }

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            if let endpoint = self.lastEndpoint {
                await self.connectToEndpoint(endpoint)
            } else if let ip = self.lastHostIP {
                await self.connectToHost(ip: ip, port: self.lastHostPort)
            }
        }
    }

    private func scheduleHostRestart() {
        hostRestartTask?.cancel()
        guard mode != .host else {
            // mode уже сброшен в .idle перед вызовом этой функции при .failed,
            // но на всякий случай не планируем повторный рестарт, если сервер
            // уже успешно поднят повторно кем-то другим.
            return
        }

        hostRestartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            _ = await self.startServer(port: self.currentServerPort, serviceName: self.currentServiceName)
        }
    }
}