import Foundation
import Combine
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .splash
    @Published var selectedRole: UserRole?

    @Published var hostNickname: String = "Ведущий"
    @Published var playerNickname: String = ""
    @Published var hostIP: String = ""
    @Published var port: String = "5000"

    @Published var players: [PlayerInfo] = []
    @Published var currentQuestion: QuestionPayload?
    @Published var selectedAnswerIndex: Int?
    @Published var lastResult: AnswerResultPayload?
    @Published var connectionHint: String = ""

    let localPlayerID = UUID()
    let network = NetworkManager()

    // Для хоста: результаты ответов от игроков.
    @Published var hostReceivedAnswers: [AnswerPayload] = []

    init() {
        network.onEvent = { [weak self] event in
            guard let self else { return }
            self.handle(event)
        }
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
    }

    func resetToRoleSelection() {
        network.stopAll()
        players.removeAll()
        currentQuestion = nil
        selectedAnswerIndex = nil
        lastResult = nil
        hostReceivedAnswers.removeAll()
        selectedRole = nil
        phase = .roleSelection
    }

    func startHosting() {
        guard let portValue = UInt16(port) else {
            connectionHint = "Неверный порт"
            return
        }

        Task {
            await network.startServer(port: portValue)
            connectionHint = "Сервер запущен на порту \(portValue)"
        }
    }

    func startGameAsHost() {
        guard players.count >= 2 else { return }
        phase = .hostControl

        Task {
            let msg = GameMessage(kind: .gameStarted, senderID: localPlayerID, senderNickname: hostNickname)
            await network.send(msg)
        }
    }

    func connectAsPlayer() {
        guard !playerNickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            connectionHint = "Введите ник"
            return
        }
        guard let portValue = UInt16(port) else {
            connectionHint = "Неверный порт"
            return
        }

        Task {
            await network.connectToHost(ip: hostIP, port: portValue)
            try? await Task.sleep(nanoseconds: 500_000_000)

            let me = PlayerInfo(id: localPlayerID, nickname: playerNickname)
            let hello = GameMessage(kind: .hello, senderID: localPlayerID, senderNickname: playerNickname, player: me)
            await network.send(hello)

            connectionHint = "Подключение к \(hostIP):\(portValue)"
            phase = .playerWaiting
        }
    }

    func sendQuestionFromHost(category: String, text: String, options: [String], correctIndex: Int?) {
        let cleanOptions = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard cleanOptions.count == 4, cleanOptions.allSatisfy({ !$0.isEmpty }) else { return }

        let question = QuestionPayload(category: category, text: text, options: cleanOptions, correctIndex: correctIndex)
        currentQuestion = question
        hostReceivedAnswers.removeAll()

        Task {
            let msg = GameMessage(kind: .question, senderID: localPlayerID, senderNickname: hostNickname, question: question)
            await network.send(msg)
        }
    }

    func sendAnswer(_ index: Int) {
        guard let question = currentQuestion else { return }
        selectedAnswerIndex = index

        let answer = AnswerPayload(questionID: question.id, playerID: localPlayerID, selectedIndex: index)
        Task {
            let msg = GameMessage(kind: .answer, senderID: localPlayerID, senderNickname: playerNickname, answer: answer)
            await network.send(msg)
        }
    }

    func evaluateAnswersAsHost() {
        guard let question = currentQuestion, let correct = question.correctIndex else { return }

        for answer in hostReceivedAnswers where answer.questionID == question.id {
            let result = AnswerResultPayload(
                questionID: question.id,
                isCorrect: answer.selectedIndex == correct,
                correctIndex: correct
            )
            let msg = GameMessage(kind: .answerResult, senderID: localPlayerID, senderNickname: hostNickname, answerResult: result)

            Task {
                await network.send(msg)
            }
        }
    }

    private func handle(_ event: NetworkEvent) {
        switch event {
        case .playerConnected(let player):
            if !players.contains(where: { $0.id == player.id }) {
                players.append(player)
            }
            broadcastPlayersIfHost()

        case .playerDisconnected(let player):
            players.removeAll { $0.id == player.id }
            broadcastPlayersIfHost()

        case .message(let msg):
            switch msg.kind {
            case .playerList:
                players = msg.players ?? []

            case .gameStarted:
                if selectedRole == .player {
                    phase = .playerWaiting
                }

            case .question:
                currentQuestion = msg.question
                selectedAnswerIndex = nil
                lastResult = nil
                if selectedRole == .player {
                    phase = .playerQuestion
                }

            case .answer:
                if selectedRole == .host, let answer = msg.answer {
                    hostReceivedAnswers.append(answer)
                }

            case .answerResult:
                if selectedRole == .player {
                    lastResult = msg.answerResult
                }

            case .error:
                connectionHint = msg.text ?? "Ошибка сети"

            default:
                break
            }
        }
    }

    private func broadcastPlayersIfHost() {
        guard selectedRole == .host else { return }

        Task {
            let msg = GameMessage(kind: .playerList, senderID: localPlayerID, senderNickname: hostNickname, players: players)
            await network.send(msg)
        }
    }
}
