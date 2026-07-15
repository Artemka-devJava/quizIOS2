import SwiftUI

struct HostControlView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Панель ведущего")
                    .font(.title2.bold())

                Text("Вопросы задаются устно/внешне. В приложении — только управление раундом и очки.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button(viewModel.roundIsOpen ? "Раунд открыт" : "Открыть раунд") {
                        viewModel.openRoundAsHost()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.roundIsOpen)

                    Button("Закрыть раунд") {
                        viewModel.closeRoundAsHost()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.roundIsOpen)
                }

                GroupBox("Кто отвечает") {
                    if let responder = viewModel.activeResponder {
                        VStack(spacing: 10) {
                            Text("Первым нажал: \(responder.nickname)")
                                .font(.headline)

                            HStack(spacing: 10) {
                                Button("Ответ верный (+1)") {
                                    viewModel.judgeCurrentResponder(isCorrect: true)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)

                                Button("Ответ неверный") {
                                    viewModel.judgeCurrentResponder(isCorrect: false)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.roundIsOpen ? "Ожидание кнопки «Ответить»" : "Раунд закрыт")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("Порядок первых нажатий") {
                    if viewModel.buzzHistory.isEmpty {
                        Text("Пока никто не нажал")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(viewModel.buzzHistory.enumerated()), id: \.offset) { index, player in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(player.nickname)
                                Spacer()
                            }
                            if index < viewModel.buzzHistory.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                GroupBox("Счёт") {
                    if viewModel.players.isEmpty {
                        Text("Игроки не подключены")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(sortedPlayers, id: \.id) { player in
                            HStack {
                                Text(player.nickname)
                                Spacer()
                                Text("\(viewModel.score(for: player.id))")
                                    .bold()
                            }
                            if player.id != sortedPlayers.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if let result = viewModel.lastResult,
                   let player = viewModel.players.first(where: { $0.id == result.playerID }) {
                    Text(result.isCorrect ? "✅ \(player.nickname): +\(result.awardedPoints)" : "❌ \(player.nickname): неверно")
                        .font(.caption)
                        .foregroundStyle(result.isCorrect ? .green : .red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Завершить и выйти") {
                    viewModel.resetToRoleSelection()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Управление раундом")
    }

    private var sortedPlayers: [PlayerInfo] {
        viewModel.players.sorted {
            let leftScore = viewModel.score(for: $0.id)
            let rightScore = viewModel.score(for: $1.id)
            if leftScore == rightScore {
                return $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
            }
            return leftScore > rightScore
        }
    }
}

#Preview {
    NavigationStack {
        HostControlView(viewModel: AppViewModel())
    }
}
