import Foundation
import Combine
import Network
import dnssd

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

/// Потокобезопасный "one-shot" резолвер continuation — гарантирует единственный resume()
/// даже если callback ядра и таймаут-фолбэк сработают одновременно с разных очередей.
private final class ResumeOnce: @unchecked Sendable {
    private let continuation: CheckedContinuation<Void, Never>
    private var didResume = false
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume()
    }
}

@MainActor
final class NetworkManager: ObservableObject {
    static let defaultPort: UInt16 = 5000
    static let serviceType = "_yaznayu._tcp"

    private static let maxHostRestartAttempts = 5

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

    private var lastEndpoint: NWEndpoint?

    private var reconnectTask: Task<Void, Never>?
    private var hostRestartTask: Task<Void, Never>?
    private var hostRestartAttempts = 0
    private var lastFailureDescription = ""

    /// Защита от повторного входа: не даём двум startServer() гоняться за одним портом.
    private var isStartingServer = false

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

    func startServer(port: UInt16 = NetworkManager.defaultPort, serviceName: String) async {
        // Не даём запустить второй listener, пока первый ещё поднимается/переподнимается.
        guard !isStartingServer else { return }
        isStartingServer = true
        defer { isStartingServer = false }

        hostRestartTask?.cancel()
        hostRestartTask = nil

        // Дожидаемся полной остановки предыдущего listener'а на уровне ОС, прежде чем биндиться
        // на тот же порт заново (иначе bind падает с "Address already in use").
        await cancelCurrentListenerAndWait()
        disconnectAllPeers()

        mode = .host
        status = .connecting

        currentServerPort = port
        let trimmedName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        currentServiceName = trimmedName.isEmpty ? "Host" : trimmedName

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                status = .failed("Неверный порт")
                return
            }

            let listener = try NWListener(using: parameters, on: nwPort)
            self.listener = listener

            listener.service = NWListener.Service(
                name: currentServiceName,
                type: NetworkManager.serviceType,
                domain: nil,
                txtRecord: nil
            )

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self.status = .connected
                        self.hostRestartAttempts = 0
                        self.lastFailureDescription = ""
                    case .failed(let error):
                        let message = self.describeNetworkError(error, context: "Сервер")
                        self.lastFailureDescription = message
                        self.status = .failed(message)
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
            let message = describeNetworkError(error, context: "Сервер")
            lastFailureDescription = message
            status = .failed(message)
            scheduleHostRestart()
        }
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
                    self.status = .failed(self.describeNetworkError(error, context: "Поиск серверов"))
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

    func stopAll() {
        hostRestartTask?.cancel()
        hostRestartTask = nil
        hostRestartAttempts = 0
        lastFailureDescription = ""
        reconnectTask?.cancel()
        reconnectTask = nil

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
                    print("——— [Net] Отправлено kind=\(message.kind.rawValue) одному peer'у")
                } else {
                    print("——— [Net] Отправка kind=\(message.kind.rawValue) всем peers (\(peers.count))")
                    for (_, peer) in peers {
                        try await sendRaw(framed, over: peer.connection)
                    }
                }
            } else if mode == .client, let clientPeer {
                try await sendRaw(framed, over: clientPeer.connection)
                print("——— [Net] Отправлено kind=\(message.kind.rawValue) хосту")
            }
        } catch {
            print("——— [Net] Ошибка отправки kind=\(message.kind.rawValue): \(error)")
            status = .failed(describeNetworkError(error, context: "Отправка"))
            if mode == .client {
                scheduleClientReconnect()
            }
        }
    }

    /// Переводит системные сетевые ошибки в понятные пользователю сообщения.
    /// В частности распознаёт NWError.dns(kDNSServiceErr_NoAuth) (-65555) — это не сбой сети,
    /// а отсутствие разрешения "Локальная сеть" в Настройках приватности iOS.
    private func describeNetworkError(_ error: Error, context: String) -> String {
        if let nwError = error as? NWError,
           case .dns(let code) = nwError,
           code == kDNSServiceErr_NoAuth {
            return "Нет доступа к локальной сети. Откройте Настройки → Конфиденциальность и безопасность → Локальная сеть и включите доступ для «Я знаю», затем нажмите «Перезапустить сервер»."
        }
        return "\(context): \(error.localizedDescription)"
    }

    /// Отменяет текущий listener и ждёт подтверждения (.cancelled) от ядра,
    /// прежде чем возвращать управление — чтобы следующий bind на тот же порт не упал
    /// с "Address already in use". Есть защитный таймаут на случай, если callback не придёт.
    private func cancelCurrentListenerAndWait() async {
        guard let oldListener = listener else { return }
        listener = nil

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumeOnce = ResumeOnce(continuation)

            oldListener.stateUpdateHandler = { state in
                if case .cancelled = state {
                    resumeOnce.resume()
                }
            }
            oldListener.cancel()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                resumeOnce.resume()
            }
        }
    }

    private func disconnectAllPeers() {
        for (_, peer) in peers {
            peer.connection.cancel()
        }
        peers.removeAll()
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
                    self.status = .failed(self.describeNetworkError(error, context: "Клиент"))
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

    /// Ник считается занятым, если совпадает (без учёта регистра) с ником уже подключённого
    /// игрока или с ником самого ведущего — иначе на скорборде было бы не различить, кто есть кто.
    private func isNicknameTaken(_ nickname: String, excluding peer: PeerConnection) -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        let takenByPeer = peers.values.contains { existingPeer in
            existingPeer !== peer &&
            existingPeer.playerInfo?.nickname
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }
        let takenByHost = trimmed.caseInsensitiveCompare(
            currentServiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        ) == .orderedSame

        return takenByPeer || takenByHost
    }

    /// Отправляет отклонённому клиенту причину отказа и закрывает соединение, дав пакету время уйти.
    private func rejectDuplicateName(_ nickname: String, peer: PeerConnection) {
        let errorMsg = GameMessage(
            kind: .error,
            senderID: UUID(),
            text: "Ник \"\(nickname)\" уже занят. Выберите другой."
        )
        Task { [weak self] in
            guard let self else { return }
            if let data = try? self.encoder.encode(errorMsg) {
                var framed = data
                framed.append(0x0A)
                try? await self.sendRaw(framed, over: peer.connection)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.removePeer(peer.id)
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
                    self.status = .failed(self.describeNetworkError(error, context: isClient ? "Клиент" : "Сервер"))
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
                print("——— [Net] Получено сообщение: kind=\(msg.kind.rawValue) sender=\(msg.senderNickname ?? "?") player=\(msg.player?.nickname ?? "-")")
                if msg.kind == .hello, let player = msg.player {
                    if mode == .host, isNicknameTaken(player.nickname, excluding: peer) {
                        print("——— [Net] HELLO отклонён: ник \"\(player.nickname)\" уже занят")
                        rejectDuplicateName(player.nickname, peer: peer)
                        continue
                    }
                    peer.playerInfo = player
                    onEvent?(.playerConnected(player))
                }
                onEvent?(.message(msg))
            } catch {
                // Печатаем и сырой JSON, и полную ошибку декодирования в консоль Xcode —
                // localizedDescription в UI слишком краток, чтобы понять причину.
                let rawJSON = String(data: messageData, encoding: .utf8) ?? "<не UTF-8: \(messageData.count) байт>"
                print("——— [Decode] Не удалось декодировать GameMessage ———")
                print("——— [Decode] Сырые данные: \(rawJSON)")
                print("——— [Decode] Ошибка: \(error)")
                print("———————————————————————————————————————————")
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
            guard let self, !Task.isCancelled else { return }
            if let endpoint = self.lastEndpoint {
                await self.connectToEndpoint(endpoint)
            }
        }
    }

    private func scheduleHostRestart() {
        hostRestartTask?.cancel()
        guard mode == .host else { return }

        hostRestartAttempts += 1
        guard hostRestartAttempts <= NetworkManager.maxHostRestartAttempts else {
            let reason = lastFailureDescription.isEmpty
                    ? "Не удалось запустить сервер на порту \(currentServerPort)."
                    : lastFailureDescription
            status = .failed(reason)
            return
        }

        // Небольшой нарастающий бэкофф вместо фиксированных 2с, чтобы не спамить лог при затяжном конфликте порта
        // или пока пользователь не ответит на системный запрос разрешения "Локальная сеть".
        let delaySeconds = min(1.5 * Double(hostRestartAttempts), 6.0)
        let delayNanos = UInt64(delaySeconds * 1_000_000_000)

        hostRestartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard let self, !Task.isCancelled else { return }
            await self.startServer(port: self.currentServerPort, serviceName: self.currentServiceName)
        }
    }
}