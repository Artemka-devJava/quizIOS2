import SwiftUI

struct HostLobbyView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Лобби ведущего")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Label("Настройки", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
            }

            TextField("Имя ведущего", text: $viewModel.hostNickname)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Порт")
                Spacer()
                Text(viewModel.hostPortText)
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
        .sheet(isPresented: $showSettings) {
            HostSettingsSheet(viewModel: viewModel)
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

private struct HostSettingsSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер") {
                    TextField("Имя ведущего", text: $viewModel.hostNickname)
                    TextField("Порт", text: $viewModel.hostPortText)
                        .keyboardType(.numberPad)
                    Text("Текущий: \(viewModel.hostPortText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Применить и перезапустить сервер") {
                        viewModel.applyHostSettings()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Настройки ведущего")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HostLobbyView(viewModel: AppViewModel())
    }
}
