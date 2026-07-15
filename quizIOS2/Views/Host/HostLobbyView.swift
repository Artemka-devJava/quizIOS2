import SwiftUI

struct HostLobbyView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Лобби ведущего")
                .font(.title2.bold())

            TextField("Имя ведущего", text: $viewModel.hostNickname)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Статический порт")
                Spacer()
                Text("\(NetworkManager.fixedPort)")
                    .font(.headline)
            }
            .padding(.horizontal, 2)

            Button("Перезапустить сервер") {
                viewModel.startHosting()
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Text("Игроков: \(viewModel.players.count)")
                Spacer()
                Text(statusText)
                    .foregroundStyle(.secondary)
            }

            List(viewModel.players) { player in
                Text(player.nickname)
            }
            .frame(minHeight: 180)

            Button("Начать игру") {
                viewModel.startGameAsHost()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.players.isEmpty)

            Text(viewModel.players.isEmpty ? "Подключите хотя бы 1 игрока для старта" : "Можно начинать игру")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(viewModel.connectionHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Назад") {
                viewModel.resetToRoleSelection()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Ведущий")
        .onAppear {
            if viewModel.network.mode != .host || viewModel.network.status == .disconnected {
                viewModel.startHosting()
            }
        }
    }

    private var statusText: String {
        switch viewModel.network.status {
        case .connected: return "Сервер активен"
        case .connecting: return "Запуск..."
        case .disconnected: return "Отключено"
        case .failed(let reason): return "Ошибка: \(reason)"
        }
    }
}

#Preview {
    NavigationStack {
        HostLobbyView(viewModel: AppViewModel())
    }
}
