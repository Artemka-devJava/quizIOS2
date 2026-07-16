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
        self.answerResult = answerResult
        self.scoreValue = scoreValue
        self.text = text
        self.sentAt = sentAt
    }
}
