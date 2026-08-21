//
//  quizIOS2Tests.swift
//  quizIOS2Tests
//
//  Created by inv on 15.07.2026.
//

import XCTest
@testable import quizIOS2

final class quizIOS2Tests: XCTestCase {

    func testGameMessageEncodingDecoding_RoundOpened() throws {
        let source = GameMessage(
            kind: .roundOpened,
            senderID: UUID(),
            senderNickname: "Host"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(source)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .roundOpened)
        XCTAssertEqual(decoded.senderNickname, "Host")
    }

    func testGameMessageEncodingDecoding_Buzz() throws {
        let player = PlayerInfo(id: UUID(), nickname: "Игрок 1")

        let source = GameMessage(
            kind: .buzz,
            senderID: player.id,
            senderNickname: player.nickname,
            player: player
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(source)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .buzz)
        XCTAssertEqual(decoded.player?.id, player.id)
        XCTAssertEqual(decoded.player?.nickname, player.nickname)
    }

    func testAnswerResultPayload_CorrectAnswer() {
        let playerID = UUID()
        let result = AnswerResultPayload(playerID: playerID, isCorrect: true, awardedPoints: 1)

        XCTAssertEqual(result.playerID, playerID)
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.awardedPoints, 1)
    }

    func testAnswerResultPayload_IncorrectAnswer() {
        let playerID = UUID()
        let result = AnswerResultPayload(playerID: playerID, isCorrect: false, awardedPoints: 0)

        XCTAssertEqual(result.playerID, playerID)
        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(result.awardedPoints, 0)
    }

    func testGameMessageEncodingDecoding_AnswerResult() throws {
        let player = PlayerInfo(id: UUID(), nickname: "Игрок 2")
        let result = AnswerResultPayload(playerID: player.id, isCorrect: true, awardedPoints: 1)

        let source = GameMessage(
            kind: .answerResult,
            senderID: UUID(),
            senderNickname: "Host",
            player: player,
            answerResult: result,
            scoreValue: 3
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(source)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .answerResult)
        XCTAssertEqual(decoded.answerResult?.isCorrect, true)
        XCTAssertEqual(decoded.answerResult?.awardedPoints, 1)
        XCTAssertEqual(decoded.scoreValue, 3)
    }
}