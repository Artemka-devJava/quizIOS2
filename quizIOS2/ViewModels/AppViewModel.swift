import Foundation
import Combine
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .splash
    @Published var selectedRole: UserRole?

    @Published var hostNickname: String = "Ведущий"
    @Published var hostPortText: String = "\(NetworkManager.defaultPort)"
    @Published var playerNickname: String = ""
    @Published var selectedServerID: String?

    @Published var players: [PlayerInfo] = []
    @Published var connectionHint: String = ""

    /// Собственный IP-адрес хоста в текущей Wi-Fi-сети — показывается игрокам
    /// для ручного подключения/QR как запасной вариант, если у них не сработает автопоиск.
    @Published var hostLocalIp: String?

    // Состояние раунда (без ввода вопросов внутри приложения)
    @Published var roundIsOpen = false
    @Published var activeResponder: PlayerInfo?
    @Published var buzzHistory: [PlayerInfo] = []
    @Published var lastResult: AnswerResultPayload?
    @Published var scores: [UUID: Int] = [:]

    // Локальное состояние игрока в текущем раунде
    @Published var localHasAttemptedInRound = false
    @Published var localIsCurrentResponder = false

    let localPlayerID = UUID()
    let network = NetworkManager()

    // Серверная защита: кто уже нажимал в текущем открытом раунде.
    private var attemptedPlayerIDsInRound: Set<UUID> = []

    private var cancellables: Set<AnyCancellable> = []

    init() {
        network.onEvent = { [weak self] event in
            guard let self else { return }
            self.handle(event)
        }

        // Пробрасываем изменения вложенного ObservableObject в UI ViewModel.
        network.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func bootSplash() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.phase = .roleSelection
        }
    }

    func choose(role: UserRole) {
        selectedRole = role
        phase = (role == .host) ? .hostLobby : .playerJoin

        if role == .player {
            refreshServerDiscovery()
            connectionHint = "Поиск ведущих в локальной сети..."
        }
    }

    func resetToRoleSelection() {
        network.stopAll()
        players.removeAll()
        selectedServerID = nil
        selectedRole = nil
        connectionHint = ""

        roundIsOpen = false
        activeResponder = nil
        buzzHistory.removeAll()
        lastResult = nil
        scores.removeAll()

        localHasAttemptedInRound = false
        localIsCurrentResponder = false
        attemptedPlayerIDsInRound.removeAll()
        hostLocalIp = nil

        phase = .roleSelection
    }

    func startHosting() {
        guard let port = UInt16(hostPortText), port > 0 else {
            connectionHint = "Неверный порт"
            return
        }

        Task {
            await network.startServer(port: port, serviceName: hostNickname)
            connectionHint = "Сервер \"\(hostNickname)\" запущен"
            hostLocalIp = network.getLocalIPv4Address()
        }
    }

    func applyHostSettings() {
        startHosting()
    }

    func refreshServerDiscovery() {
        network.startBrowsingServers()
        network.startSubnetScan()
    }

    func startGameAsHost() {
        guard players.count >= 1 else {
            print("——— [Net] startGameAsHost: отменено, players пуст в момент вызова")
            connectionHint = "Нужен хотя бы 1 подключённый игрок"
            return
        }

        print("——— [Net] startGameAsHost: отправка gameStarted, игроков=\(players.count)")
        phase = .hostControl
        // С этого момента новые подключения отклоняются — нельзя зайти посреди игры.
        network.gameInProgress = true

        Task {
            let msg = GameMessage(kind: .gameStarted, senderID: localPlayerID, senderNickname: hostNickname)
            await network.send(msg)
        }
    }

    func openRoundAsHost() {
        roundIsOpen = true
        activeResponder = nil
        buzzHistory.removeAll()
        lastResult = nil

        localHasAttemptedInRound = false
        localIsCurrentResponder = false
        attemptedPlayerIDsInRound.removeAll()

        Task {
            let msg = GameMessage(kind: .roundOpened, senderID: localPlayerID, senderNickname: hostNickname)
            await network.send(msg)
        }
    }

    func closeRoundAsHost() {
        roundIsOpen = false
        activeResponder = nil

        localIsCurrentResponder = false
        attemptedPlayerIDsInRound.removeAll()

        Task {
            let msg = GameMessage(kind: .roundClosed, senderID: localPlayerID, senderNickname: hostNickname)
            await network.send(msg)
        }
    }

    func judgeCurrentResponder(isCorrect: Bool) {
        guard selectedRole == .host, let responder = activeResponder else { return }

        if isCorrect {
            let newScore = (scores[responder.id] ?? 0) + 1
            scores[responder.id] = newScore
            roundIsOpen = false

            let result = AnswerResultPayload(playerID: responder.id, isCorrect: true, awardedPoints: 1)
            lastResult = result

            Task {
                let msg = GameMessage(
                    kind: .answerResult,
                    senderID: localPlayerID,
                    senderNickname: hostNickname,
                    player: responder,
                    answerResult: result,
                    scoreValue: newScore,
                    text: "Верный ответ"
                )
                await network.send(msg)

                let close = GameMessage(kind: .roundClosed, senderID: localPlayerID, senderNickname: hostNickname)
                await network.send(close)
            }

            activeResponder = nil
            localIsCurrentResponder = false
            attemptedPlayerIDsInRound.removeAll()
        } else {
            let result = AnswerResultPayload(playerID: responder.id, isCorrect: false, awardedPoints: 0)
            lastResult = result
            activeResponder = nil
            localIsCurrentResponder = false

            Task {
                let resultMsg = GameMessage(
                    kind: .answerResult,
                    senderID: localPlayerID,
                    senderNickname: hostNickname,
                    player: responder,
                    answerResult: result,
                    text: "Неверный ответ"
                )
                await network.send(resultMsg)

                let clearMsg = GameMessage(kind: .responderCleared, senderID: localPlayerID, senderNickname: hostNickname)
                await network.send(clearMsg)
            }
        }
    }

    func connectAsPlayer() {
        guard !playerNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionHint = "Введите ник"
            return
        }

        guard let selectedServerID else {
            connectionHint = "Выберите сервер из списка"
            return
        }

        let serverName = network.discoveredServers.first(where: { $0.id == selectedServerID })?.name ?? "ведущий"

        Task {
            await network.connectToDiscoveredServer(id: selectedServerID)
            await joinAfterConnecting(displayName: serverName)
        }
    }

    /// Подключение вручную по IP:порт — резервный путь для сетей, где Bonjour/mDNS
    /// не доходит между устройствами (например, Wi-Fi-хотспот с телефона: сам хотспот
    /// обычно не пробрасывает multicast-трафик от раздающего телефона к клиенту).
    func connectAsPlayerManual(_ hostText: String) {
        guard !playerNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionHint = "Введите ник"
            return
        }

        let trimmed = hostText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            connectionHint = "Введите IP-адрес хоста"
            return
        }

        let components = trimmed.split(separator: ":")
        let ip = String(components.first ?? "")
        let port = components.count > 1 ? (UInt16(components[1]) ?? NetworkManager.defaultPort) : NetworkManager.defaultPort
        guard !ip.isEmpty else {
            connectionHint = "Неверный формат. Пример: 192.168.1.5:5000"
            return
        }

        Task {
            await network.connectToServer(ip: ip, port: port)
            await joinAfterConnecting(displayName: ip)
        }
    }

    private func joinAfterConnecting(displayName: String) async {
        try? await Task.sleep(nanoseconds: 500_000_000)

        let me = PlayerInfo(id: localPlayerID, nickname: playerNickname)
        let hello = GameMessage(kind: .hello, senderID: localPlayerID, senderNickname: playerNickname, player: me)
        await network.send(hello)

        connectionHint = "Подключение к \(displayName)"
        phase = .playerWaiting
    }

    func playerPressedAnswerButton() {
        guard selectedRole == .player else { return }
        guard roundIsOpen, activeResponder == nil, !localHasAttemptedInRound else { return }

        localHasAttemptedInRound = true

        let me = PlayerInfo(id: localPlayerID, nickname: playerNickname)
        Task {
            let msg = GameMessage(kind: .buzz, senderID: localPlayerID, senderNickname: playerNickname, player: me)
            await network.send(msg)
        }
    }

    func score(for playerID: UUID) -> Int {
        scores[playerID] ?? 0
    }

    private func handle(_ event: NetworkEvent) {
        switch event {
        case .playerConnected(let player):
            if !players.contains(where: { $0.id == player.id }) {
                players.append(player)
            }
            if scores[player.id] == nil {
                scores[player.id] = 0
            }
            broadcastPlayersIfHost()

        case .playerDisconnected(let player):
            players.removeAll { $0.id == player.id }
            attemptedPlayerIDsInRound.remove(player.id)
            if activeResponder?.id == player.id {
                activeResponder = nil
                localIsCurrentResponder = false
            }
            broadcastPlayersIfHost()

        case .hostConnectionLost(let wasConnected):
            // Хост вышел из игры/закрыл приложение, или сеть легла — соединение
            // разорвано не по инициативе игрока. Автоматически возвращаем его
            // на экран поиска, а не оставляем висеть в ожидании ответа хоста.
            if selectedRole == .player {
                returnPlayerToJoinScreen(wasConnected ? "Ведущий покинул игру" : "Не удалось подключиться к ведущему")
            }

        case .message(let msg):
            switch msg.kind {
            case .hello:
                // hello обрабатывается на сетевом уровне для регистрации игрока.
                break

            case .playerList:
                players = msg.players ?? []
                for player in players where scores[player.id] == nil {
                    scores[player.id] = 0
                }

            case .gameStarted:
                if selectedRole == .player {
                    phase = .playerQuestion
                    connectionHint = "Игра началась. Ждите открытия раунда"
                }

            case .roundOpened:
                roundIsOpen = true
                activeResponder = nil
                lastResult = nil
                localHasAttemptedInRound = false
                localIsCurrentResponder = false
                attemptedPlayerIDsInRound.removeAll()
                if selectedRole == .player {
                    phase = .playerQuestion
                }

            case .buzz:
                // Серверная блокировка: один игрок не может нажать второй раз в одном открытом раунде.
                guard selectedRole == .host,
                      roundIsOpen,
                      activeResponder == nil,
                      let player = msg.player,
                      !attemptedPlayerIDsInRound.contains(player.id) else { break }

                attemptedPlayerIDsInRound.insert(player.id)
                activeResponder = player
                buzzHistory.append(player)

                Task {
                    let selectMsg = GameMessage(
                        kind: .responderSelected,
                        senderID: localPlayerID,
                        senderNickname: hostNickname,
                        player: player,
                        text: "Отвечает \(player.nickname)"
                    )
                    await network.send(selectMsg)
                }

            case .responderSelected:
                activeResponder = msg.player
                localIsCurrentResponder = (msg.player?.id == localPlayerID)

            case .responderCleared:
                activeResponder = nil
                localIsCurrentResponder = false

            case .roundClosed:
                roundIsOpen = false
                activeResponder = nil
                localIsCurrentResponder = false
                attemptedPlayerIDsInRound.removeAll()

            case .answerResult:
                lastResult = msg.answerResult
                if let player = msg.player,
                   let scoreValue = msg.scoreValue,
                   msg.answerResult?.isCorrect == true {
                    scores[player.id] = scoreValue
                }

            case .error:
                if selectedRole == .player, phase != .playerQuestion {
                    returnPlayerToJoinScreen(msg.text ?? "Ошибка сети")
                } else {
                    connectionHint = msg.text ?? "Ошибка сети"
                }
            }
        }
    }

    /// Возвращает игрока на экран поиска хоста, сбрасывая состояние игры/раунда —
    /// используется и при явной ошибке от сервера (ник занят и т.п.), и при потере
    /// соединения с хостом.
    private func returnPlayerToJoinScreen(_ hint: String) {
        network.stopAll()
        selectedServerID = nil
        players.removeAll()

        roundIsOpen = false
        activeResponder = nil
        buzzHistory.removeAll()
        lastResult = nil
        localHasAttemptedInRound = false
        localIsCurrentResponder = false
        attemptedPlayerIDsInRound.removeAll()

        phase = .playerJoin
        connectionHint = hint
        refreshServerDiscovery()
    }

    private func broadcastPlayersIfHost() {
        guard selectedRole == .host else { return }

        Task {
            let msg = GameMessage(kind: .playerList, senderID: localPlayerID, senderNickname: hostNickname, players: players)
            await network.send(msg)
        }
    }
}