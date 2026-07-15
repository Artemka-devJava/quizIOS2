import SwiftUI

struct PlayerJoinView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 14) {
            Text("Подключение игрока")
                .font(.title2.bold())

            TextField("Ваш ник", text: $viewModel.playerNickname)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Найденные ведущие")
                    .font(.headline)
                Spacer()
                Button("Обновить") {
                    viewModel.refreshServerDiscovery()
                }
            }

            if viewModel.network.discoveredServers.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Идёт поиск в локальной Wi-Fi сети...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                List(viewModel.network.discoveredServers) { server in
                    Button {
                        viewModel.selectedServerID = server.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                Text(server.details)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedServerID == server.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 180)
            }

            Button("Подключиться") {
                viewModel.connectAsPlayer()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedServerID == nil)

            Text(viewModel.connectionHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Назад") {
                viewModel.resetToRoleSelection()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Я игрок")
        .onAppear {
            viewModel.refreshServerDiscovery()
        }
    }
}

#Preview {
    NavigationStack {
        PlayerJoinView(viewModel: AppViewModel())
    }
}
