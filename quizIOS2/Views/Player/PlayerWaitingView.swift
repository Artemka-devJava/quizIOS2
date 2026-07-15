import SwiftUI

struct PlayerWaitingView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Ожидание вопроса от ведущего")
                .font(.headline)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Отключиться") {
                viewModel.resetToRoleSelection()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Ожидание")
    }

    private var statusText: String {
        switch viewModel.network.status {
        case .connected: return "Соединение активно"
        case .connecting: return "Подключение..."
        case .disconnected: return "Соединение потеряно"
        case .failed(let reason): return "Ошибка: \(reason)"
        }
    }
}

#Preview {
    NavigationStack {
        PlayerWaitingView(viewModel: AppViewModel())
    }
}

