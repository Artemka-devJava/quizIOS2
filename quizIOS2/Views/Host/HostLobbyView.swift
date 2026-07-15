import SwiftUI

struct HostLobbyView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Лобби ведущего")
                .font(.title2.bold())

            TextField("Имя ведущего", text: $viewModel.hostNickname)
                .textFieldStyle(.roundedBorder)

            TextField("Порт", text: $viewModel.port)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Button("Запустить сервер") {
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
            .disabled(viewModel.players.count < 2)

            Button("Назад") {
                viewModel.resetToRoleSelection()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Ведущий")
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

