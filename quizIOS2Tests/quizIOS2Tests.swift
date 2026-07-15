//
//  quizIOS2Tests.swift
//  quizIOS2Tests
//
//  Created by inv on 15.07.2026.
//

import XCTest
@testable import quizIOS2

final class quizIOS2Tests: XCTestCase {

    func testGameMessageEncodingDecoding() throws {
        let question = QuestionPayload(
            category: "Музыка и поп-культура",
            text: "Какой трек стал вирусным в TikTok в 2020-м?",
            options: ["Sorry", "Yummy", "Peaches", "Baby"],
            correctIndex: 1
        )

        let source = GameMessage(
            kind: .question,
            senderID: UUID(),
            senderNickname: "Host",
            question: question
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(source)
        let decoded = try decoder.decode(GameMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .question)
        XCTAssertEqual(decoded.question?.text, question.text)
        XCTAssertEqual(decoded.question?.options.count, 4)
        XCTAssertEqual(decoded.question?.correctIndex, 1)
    }

    func testAnswerPayloadDefaults() {
        let qid = UUID()
        let pid = UUID()
        let answer = AnswerPayload(questionID: qid, playerID: pid, selectedIndex: 2)

        XCTAssertEqual(answer.questionID, qid)
        XCTAssertEqual(answer.playerID, pid)
        XCTAssertEqual(answer.selectedIndex, 2)
    }

}
