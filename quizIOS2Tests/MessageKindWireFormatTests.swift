//
//  MessageKindWireFormatTests.swift
//  quizIOS2Tests
//
//  Locks in MessageKind's raw wire-format strings against the Android side
//  (see GameModels.swift's own comment on this enum, and quizAnd's
//  GameModelsTest.kt for the mirrored check there). A round-trip
//  encode/decode test alone does NOT protect against this: Codable happily
//  round-trips any rawValue you pick, so a silent rename here would still
//  pass every other test while breaking cross-platform interop entirely —
//  exactly the bug this project hit once already.
//

import XCTest
@testable import quizIOS2

final class MessageKindWireFormatTests: XCTestCase {

    func testRawValuesMatchTheSharedWireFormat() {
        XCTAssertEqual(MessageKind.hello.rawValue, "hello")
        XCTAssertEqual(MessageKind.playerList.rawValue, "playerList")
        XCTAssertEqual(MessageKind.gameStarted.rawValue, "gameStarted")
        XCTAssertEqual(MessageKind.roundOpened.rawValue, "roundOpened")
        XCTAssertEqual(MessageKind.buzz.rawValue, "buzz")
        XCTAssertEqual(MessageKind.responderSelected.rawValue, "responderSelected")
        XCTAssertEqual(MessageKind.responderCleared.rawValue, "responderCleared")
        XCTAssertEqual(MessageKind.roundClosed.rawValue, "roundClosed")
        XCTAssertEqual(MessageKind.answerResult.rawValue, "answerResult")
        XCTAssertEqual(MessageKind.scoresReset.rawValue, "scoresReset")
        XCTAssertEqual(MessageKind.error.rawValue, "error")
    }

    func testGameMessageEncodesTheRawStringNotTheSwiftCaseName() throws {
        let msg = GameMessage(kind: .scoresReset, senderID: UUID(), senderNickname: "Host")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(msg)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("\"kind\":\"scoresReset\""))
        XCTAssertFalse(json.contains("scoresReset".uppercased()))
    }

    func testDecodingToleratesUnknownFieldsFromTheOtherPlatform() throws {
        let json = """
        {"id":"\(UUID().uuidString)","kind":"hello","senderID":"\(UUID().uuidString)",
         "sentAt":"2026-08-26T00:00:00Z","someFutureField":"ignored"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GameMessage.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.kind, .hello)
    }
}
