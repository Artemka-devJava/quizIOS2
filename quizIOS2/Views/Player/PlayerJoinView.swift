import SwiftUI

struct PlayerJoinView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 14) {
            Text("Подключение игрока")
                .font(.title2.bold())

            TextField("Ваш ник", text: $viewModel.playerNickname)
                .textFieldStyle(.roundedBorder)

            TextField("IP ведущего", text: $viewModel.hostIP)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            TextField("Порт", text: $viewModel.port)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            Button("Подключиться") {
                viewModel.connectAsPlayer()
            }
            .buttonStyle(.borderedProminent)

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
    }
}

#Preview {
    NavigationStack {
        PlayerJoinView(viewModel: AppViewModel())
    }
}

