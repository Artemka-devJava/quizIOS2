import Foundation

enum UserRole: String, Codable {
    case host
    case player
}

enum AppPhase: Equatable {
    case splash
    case roleSelection
    case hostLobby
    case hostControl
    case playerJoin
    case playerWaiting
    case playerQuestion
}

struct PlayerInfo: Identifiable, Codable, Equatable {
    let id: UUID
    var nickname: String
}

struct QuestionPayload: Codable, Equatable {
    let id: UUID
    let category: String
    let text: String
    let options: [String]
    let correctIndex: Int?

    init(id: UUID = UUID(), category: String, text: String, options: [String], correctIndex: Int? = nil) {
        self.id = id
        self.category = category
        self.text = text
        self.options = options
        self.correctIndex = correctIndex
    }
}

struct AnswerPayload: Codable, Equatable {
    let questionID: UUID
    let playerID: UUID
    let selectedIndex: Int
    let sentAt: Date

    init(questionID: UUID = UUID(), playerID: UUID, selectedIndex: Int = 0, sentAt: Date = Date()) {
        self.questionID = questionID
        self.playerID = playerID
        self.selectedIndex = selectedIndex
        self.sentAt = sentAt
    }
}

struct AnswerResultPayload: Codable, Equatable {
    let playerID: UUID
    let isCorrect: Bool
    let awardedPoints: Int
}

enum MessageKind: String, Codable {
    case hello
    case playerList
    case gameStarted
    case roundOpened
    case buzz
    case responderSelected
    case responderCleared
    case roundClosed
    case answer
    case answerResult
    case error
}

struct GameMessage: Codable {
    let id: UUID
    let kind: MessageKind
    let senderID: UUID
    let senderNickname: String?
    let player: PlayerInfo?
    let players: [PlayerInfo]?
    let question: QuestionPayload?
    let answer: AnswerPayload?
    let answerResult: AnswerResultPayload?
    let scoreValue: Int?
    let text: String?
    let sentAt: Date

    init(
        id: UUID = UUID(),
        kind: MessageKind,
        senderID: UUID,
        senderNickname: String? = nil,
        player: PlayerInfo? = nil,
        players: [PlayerInfo]? = nil,
        question: QuestionPayload? = nil,
        answer: AnswerPayload? = nil,
        answerResult: AnswerResultPayload? = nil,
        scoreValue: Int? = nil,
        text: String? = nil,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.senderID = senderID
        self.senderNickname = senderNickname
        self.player = player
        self.players = players
        self.question = question
        self.answer = answer
        self.answerResult = answerResult
        self.scoreValue = scoreValue
        self.text = text
        self.sentAt = sentAt
    }
}
