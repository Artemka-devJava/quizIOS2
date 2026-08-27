//
//  AppViewModelTests.swift
//  quizIOS2Tests
//
//  Mirrors quizAnd's AppViewModelTest.kt: drives AppViewModel by feeding
//  NetworkEvent values straight into `network.onEvent`, bypassing real
//  sockets entirely (NetworkManager's `mode` stays `.idle` since we never
//  call startServer/connectToServer, so `send()` is a harmless no-op).
//  No mocking is needed here — unlike the Android ViewModel, AppViewModel
//  doesn't take an injected Context/Application, and `@testable import`
//  already grants this test target access to every `internal` member.
//
//  Ported from Android rather than independently authored, so the two
//  platforms are asserting the exact same behavioral contract for the
//  bug-prone logic real device testing kept catching real bugs in this
//  session: buzz dedup, correct/incorrect round semantics, score surviving
//  disconnect+reconnect, and the in-lobby score reset.
//
//  UNVERIFIED: written without Mac/Xcode access, so this has not actually
//  been compiled or run. Checked only by careful manual review against the
//  real AppViewModel.swift source (line-by-line) and Swift syntax rules.
//

import XCTest
@testable import quizIOS2

@MainActor
final class AppViewModelTests: XCTestCase {

    private let alice = PlayerInfo(id: UUID(), nickname: "Alice")
    private let bob = PlayerInfo(id: UUID(), nickname: "Bob")

    private func deliver(_ viewModel: AppViewModel, _ event: NetworkEvent) {
        guard let onEvent = viewModel.network.onEvent else {
            XCTFail("network.onEvent was not wired by AppViewModel.init()")
            return
        }
        onEvent(event)
    }

    private func deliverMessage(
        _ viewModel: AppViewModel,
        kind: MessageKind,
        senderID: UUID = UUID(),
        player: PlayerInfo? = nil,
        players: [PlayerInfo]? = nil,
        answerResult: AnswerResultPayload? = nil,
        scoreValue: Int? = nil
    ) {
        let msg = GameMessage(
            kind: kind,
            senderID: senderID,
            player: player,
            players: players,
            answerResult: answerResult,
            scoreValue: scoreValue
        )
        deliver(viewModel, .message(msg))
    }

    // MARK: - connect / disconnect / score persistence (the core reconnect fix)

    func testPlayerConnectedAddsThePlayerAndSeedsScoreAtZero() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host

        deliver(viewModel, .playerConnected(alice))

        XCTAssertEqual(viewModel.players, [alice])
        XCTAssertEqual(viewModel.score(for: alice.id), 0)
    }

    func testPlayerConnectedTwiceWithSameIdDoesNotDuplicate() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host

        deliver(viewModel, .playerConnected(alice))
        deliver(viewModel, .playerConnected(alice))

        XCTAssertEqual(viewModel.players, [alice])
    }

    func testScoreSurvivesDisconnectAndReconnectWithSameId() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        deliver(viewModel, .playerConnected(alice))
        viewModel.openRoundAsHost()
        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)
        viewModel.judgeCurrentResponder(isCorrect: true)
        XCTAssertEqual(viewModel.score(for: alice.id), 1)

        deliver(viewModel, .playerDisconnected(alice))
        XCTAssertTrue(viewModel.players.isEmpty)
        XCTAssertEqual(viewModel.score(for: alice.id), 1, "score must survive disconnect")

        deliver(viewModel, .playerConnected(alice))
        XCTAssertEqual(viewModel.score(for: alice.id), 1, "reconnecting with the same id must not reset the score to 0")
    }

    func testIsKnownPlayerIdReflectsTheScoresMap() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        guard let isKnown = viewModel.network.isKnownPlayerId else {
            XCTFail("isKnownPlayerId was not wired by AppViewModel.init()")
            return
        }

        XCTAssertFalse(isKnown(UUID()))
        deliver(viewModel, .playerConnected(alice))
        XCTAssertTrue(isKnown(alice.id))
    }

    // MARK: - buzz dedup

    func testSecondBuzzInSameRoundIsIgnoredOnceResponderSelected() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        deliver(viewModel, .playerConnected(alice))
        deliver(viewModel, .playerConnected(bob))
        viewModel.openRoundAsHost()

        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)
        XCTAssertEqual(viewModel.activeResponder, alice)

        deliverMessage(viewModel, kind: .buzz, senderID: bob.id, player: bob)
        XCTAssertEqual(viewModel.activeResponder, alice, "a later buzz must not steal the responder slot")
        XCTAssertEqual(viewModel.buzzHistory, [alice])
    }

    func testOpeningNewRoundClearsPreviousResponderAndHistory() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        deliver(viewModel, .playerConnected(alice))
        viewModel.openRoundAsHost()
        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)
        XCTAssertEqual(viewModel.activeResponder, alice)

        viewModel.openRoundAsHost()

        XCTAssertNil(viewModel.activeResponder)
        XCTAssertTrue(viewModel.buzzHistory.isEmpty)
    }

    // MARK: - judging: correct closes the round, incorrect does not

    func testCorrectJudgementAwardsPointClosesRoundClearsResponder() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        deliver(viewModel, .playerConnected(alice))
        viewModel.openRoundAsHost()
        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)

        viewModel.judgeCurrentResponder(isCorrect: true)

        XCTAssertEqual(viewModel.score(for: alice.id), 1)
        XCTAssertFalse(viewModel.roundIsOpen, "a correct answer must close the round")
        XCTAssertNil(viewModel.activeResponder)
    }

    func testIncorrectJudgementLeavesRoundOpenForAnotherPlayer() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        deliver(viewModel, .playerConnected(alice))
        deliver(viewModel, .playerConnected(bob))
        viewModel.openRoundAsHost()
        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)

        viewModel.judgeCurrentResponder(isCorrect: false)

        XCTAssertEqual(viewModel.score(for: alice.id), 0)
        XCTAssertTrue(viewModel.roundIsOpen, "an incorrect answer must leave the round open, by design")
        XCTAssertNil(viewModel.activeResponder)

        deliverMessage(viewModel, kind: .buzz, senderID: bob.id, player: bob)
        XCTAssertEqual(viewModel.activeResponder, bob)
    }

    func testPlayerJudgedIncorrectCannotBuzzAgainInSameRound() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        deliver(viewModel, .playerConnected(alice))
        viewModel.openRoundAsHost()
        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)
        viewModel.judgeCurrentResponder(isCorrect: false)

        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)

        XCTAssertNil(viewModel.activeResponder, "the same player must not get a second attempt in one open round")
    }

    // MARK: - reset score in the same lobby

    func testResetScoresAsHostZeroesEveryKnownIdWithoutTouchingLobby() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .host
        deliver(viewModel, .playerConnected(alice))
        deliver(viewModel, .playerConnected(bob))
        viewModel.openRoundAsHost()
        deliverMessage(viewModel, kind: .buzz, senderID: alice.id, player: alice)
        viewModel.judgeCurrentResponder(isCorrect: true)
        deliver(viewModel, .playerDisconnected(bob))

        viewModel.resetScoresAsHost()

        XCTAssertEqual(viewModel.score(for: alice.id), 0)
        XCTAssertEqual(viewModel.score(for: bob.id), 0)
        XCTAssertEqual(
            viewModel.network.isKnownPlayerId?(bob.id), true,
            "a disconnected player's id must stay known after a reset, or their reconnect would be rejected"
        )
        XCTAssertFalse(viewModel.roundIsOpen)
        XCTAssertEqual(viewModel.players, [alice], "the lobby/connection must be untouched by a score reset")
    }

    func testResetScoresAsHostIsNoOpForAPlayer() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .player
        deliverMessage(viewModel, kind: .roundOpened)
        XCTAssertTrue(viewModel.roundIsOpen)

        viewModel.resetScoresAsHost()

        XCTAssertTrue(viewModel.roundIsOpen, "a non-host call must be a no-op")
    }

    func testReceivingScoresResetZeroesLocalMirrorAndClosesRound() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .player
        deliverMessage(viewModel, kind: .playerList, players: [alice])
        deliverMessage(
            viewModel, kind: .answerResult, player: alice,
            answerResult: AnswerResultPayload(playerID: alice.id, isCorrect: true, awardedPoints: 1),
            scoreValue: 1
        )
        deliverMessage(viewModel, kind: .roundOpened)
        XCTAssertEqual(viewModel.score(for: alice.id), 1)

        deliverMessage(viewModel, kind: .scoresReset)

        XCTAssertEqual(viewModel.score(for: alice.id), 0)
        XCTAssertFalse(viewModel.roundIsOpen)
    }

    // MARK: - player-side phase transitions

    func testGameStartedMovesPlayerIntoQuestionPhase() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .player

        deliverMessage(viewModel, kind: .gameStarted)

        XCTAssertEqual(viewModel.phase, .playerQuestion)
    }

    func testPlayerPressedAnswerButtonOnlySendsOncePerRound() {
        let viewModel = AppViewModel()
        viewModel.selectedRole = .player
        deliverMessage(viewModel, kind: .roundOpened)

        viewModel.playerPressedAnswerButton()
        XCTAssertTrue(viewModel.localHasAttemptedInRound)

        viewModel.playerPressedAnswerButton()
        XCTAssertTrue(viewModel.localHasAttemptedInRound)
    }
}
