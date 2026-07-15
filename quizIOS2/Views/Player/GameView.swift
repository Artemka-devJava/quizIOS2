import SwiftUI

struct GameView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Раунд")
                .font(.title2.bold())

            Text(viewModel.roundIsOpen ? "Раунд открыт" : "Ожидание открытия раунда")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(viewModel.roundIsOpen ? .green.opacity(0.15) : .gray.opacity(0.15), in: Capsule())

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
            } else {
                Text("Кнопка «Ответить» активна для первого нажатия")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                viewModel.playerPressedAnswerButton()
            } label: {
                Text(viewModel.localHasAttemptedInRound ? "Вы уже нажимали" : "Ответить")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canBuzz)

            if let result = viewModel.lastResult {
                if result.playerID == viewModel.localPlayerID {
                    Text(result.isCorrect ? "Верно! +\(result.awardedPoints)" : "Неверно, раунд продолжается")
                        .font(.headline)
                        .foregroundStyle(result.isCorrect ? .green : .red)
                } else {
                    Text(result.isCorrect ? "Другой игрок ответил верно" : "Ответ игрока неверный")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Выйти") {
                viewModel.resetToRoleSelection()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .animation(.easeInOut, value: viewModel.lastResult)
        .navigationTitle("Раунд")
    }

    private var canBuzz: Bool {
        viewModel.roundIsOpen && viewModel.activeResponder == nil && !viewModel.localHasAttemptedInRound
    }
}

#Preview {
    NavigationStack {
        GameView(viewModel: AppViewModel())
    }
}
