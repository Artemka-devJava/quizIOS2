import SwiftUI

struct GameView: View {
    @ObservedObject var viewModel: AppViewModel
    private let buzzFeedback = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Статус раунда
                Text(viewModel.roundIsOpen ? "Раунд открыт" : "Ожидание открытия раунда")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(viewModel.roundIsOpen ? Color.green.opacity(0.15) : Color.gray.opacity(0.15),
                                in: Capsule())
                    .animation(.easeInOut(duration: 0.25), value: viewModel.roundIsOpen)

                // Кто отвечает
                Group {
                    if let responder = viewModel.activeResponder {
                        if responder.id == viewModel.localPlayerID {
                            Text("Вы отвечаете!")
                                .font(.headline)
                                .foregroundStyle(.green)
                        } else {
                            Text("Сейчас отвечает: \(responder.nickname)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.roundIsOpen {
                        Text("Нажмите «Ответить» первым!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ожидайте открытия раунда")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: viewModel.activeResponder?.id)

                // Кнопка Ответить
                Button {
                    buzzFeedback.impactOccurred()
                    viewModel.playerPressedAnswerButton()
                } label: {
                    Text(viewModel.localHasAttemptedInRound ? "Вы уже нажимали" : "Ответить")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(canBuzz ? .blue : .gray)
                .disabled(!canBuzz)
                .animation(.spring(response: 0.3), value: canBuzz)

                // Результат
                if let result = viewModel.lastResult {
                    resultBanner(result)
                        .transition(.scale.combined(with: .opacity))
                }

                // Счёт
                if !viewModel.players.isEmpty {
                    scoreSection
                }

                Button("Выйти") {
                    viewModel.resetToRoleSelection()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding()
        }
        .animation(.easeInOut, value: viewModel.lastResult)
        .navigationTitle("Раунд")
        .onAppear { buzzFeedback.prepare() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func resultBanner(_ result: AnswerResultPayload) -> some View {
        let isMe = result.playerID == viewModel.localPlayerID
        let text: String = {
            if isMe {
                return result.isCorrect ? "✅ Верно! +\(result.awardedPoints)" : "❌ Неверно, раунд продолжается"
            } else {
                return result.isCorrect ? "Другой игрок ответил верно" : "Ответ игрока неверный"
            }
        }()
        Text(text)
            .font(.headline)
            .foregroundStyle(result.isCorrect ? Color.green : Color.red)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(result.isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10))
    }

    private var scoreSection: some View {
        GroupBox("Счёт") {
            ForEach(sortedPlayers, id: \.id) { player in
                HStack {
                    Text(player.id == viewModel.localPlayerID ? "Вы (\(player.nickname))" : player.nickname)
                        .fontWeight(player.id == viewModel.localPlayerID ? .semibold : .regular)
                    Spacer()
                    Text("\(viewModel.score(for: player.id))")
                        .bold()
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 2)
                if player.id != sortedPlayers.last?.id { Divider() }
            }
        }
    }

    // MARK: - Helpers

    private var canBuzz: Bool {
        viewModel.roundIsOpen && viewModel.activeResponder == nil && !viewModel.localHasAttemptedInRound
    }

    private var sortedPlayers: [PlayerInfo] {
        viewModel.players.sorted {
            viewModel.score(for: $0.id) > viewModel.score(for: $1.id)
        }
    }
}

#Preview {
    NavigationStack {
        GameView(viewModel: AppViewModel())
    }
}


