import SwiftUI

struct GameView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            if let q = viewModel.currentQuestion {
                Text(q.category)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15), in: Capsule())

                Text(q.text)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ForEach(Array(q.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        viewModel.sendAnswer(index)
                    } label: {
                        HStack {
                            Text(["A", "B", "C", "D"][index])
                                .font(.headline)
                                .frame(width: 34, height: 34)
                                .background(.black.opacity(0.08), in: Circle())
                            Text(option)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(backgroundColor(for: index), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedAnswerIndex != nil)
                }

                if let result = viewModel.lastResult {
                    Text(result.isCorrect ? "Верно!" : "Неверно")
                        .font(.headline)
                        .foregroundStyle(result.isCorrect ? .green : .red)
                        .transition(.opacity.combined(with: .scale))
                }
            } else {
                ProgressView("Ожидание вопроса")
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

    private func backgroundColor(for index: Int) -> Color {
        if let result = viewModel.lastResult {
            if index == result.correctIndex {
                return .green.opacity(0.2)
            }
            if viewModel.selectedAnswerIndex == index, !result.isCorrect {
                return .red.opacity(0.2)
            }
        }

        if viewModel.selectedAnswerIndex == index {
            return .blue.opacity(0.2)
        }
        return .gray.opacity(0.12)
    }
}

#Preview {
    NavigationStack {
        GameView(viewModel: AppViewModel())
    }
}

