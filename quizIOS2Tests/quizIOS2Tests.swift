//
//  quizIOS2Tests.swift
//  quizIOS2Tests
//
//  Created by inv on 15.07.2026.
//

import XCTest
@testable import quizIOS2

final class quizIOS2Tests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    // MARK: - GameMessage round-trip

    func testGameMessageHelloRoundTrip() throws {
        let playerID = UUID()
        let player = PlayerInfo(id: playerID, nickname: "Тест")
        let msg = GameMessage(kind: .hello, senderID: playerID, senderNickname: "Тест", player: player)

        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .hello)
        XCTAssertEqual(decoded.senderNickname, "Тест")
        XCTAssertEqual(decoded.player?.id, playerID)
        XCTAssertEqual(decoded.player?.nickname, "Тест")
    }

    func testGameMessageBuzzRoundTrip() throws {
        let playerID = UUID()
        let player = PlayerInfo(id: playerID, nickname: "Игрок1")
        let msg = GameMessage(kind: .buzz, senderID: playerID, senderNickname: "Игрок1", player: player)

        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .buzz)
        XCTAssertEqual(decoded.player?.id, playerID)
    }

    // MARK: - AnswerResultPayload round-trip

    func testAnswerResultPayloadRoundTrip() throws {
        let playerID = UUID()
        let result = AnswerResultPayload(playerID: playerID, isCorrect: true, awardedPoints: 1)
        let msg = GameMessage(
            kind: .answerResult,
            senderID: UUID(),
            player: PlayerInfo(id: playerID, nickname: "Игрок"),
            answerResult: result,
            scoreValue: 3
        )

        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .answerResult)
        XCTAssertEqual(decoded.answerResult?.playerID, playerID)
        XCTAssertEqual(decoded.answerResult?.isCorrect, true)
        XCTAssertEqual(decoded.answerResult?.awardedPoints, 1)
        XCTAssertEqual(decoded.scoreValue, 3)
    }

    // MARK: - PlayerInfo equality

    func testPlayerInfoEquality() {
        let id = UUID()
        let a = PlayerInfo(id: id, nickname: "Аня")
        let b = PlayerInfo(id: id, nickname: "Аня")
        let c = PlayerInfo(id: UUID(), nickname: "Боря")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - PlayerList round-trip

    func testPlayerListMessageRoundTrip() throws {
        let players = [
            PlayerInfo(id: UUID(), nickname: "Аня"),
            PlayerInfo(id: UUID(), nickname: "Боря")
        ]
        let msg = GameMessage(kind: .playerList, senderID: UUID(), players: players)

        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .playerList)
        XCTAssertEqual(decoded.players?.count, 2)
        XCTAssertEqual(decoded.players?.map(\.nickname), ["Аня", "Боря"])
    }
}
