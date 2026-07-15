import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Выберите роль")
                .font(.title.bold())

            Button {
                viewModel.choose(role: .host)
            } label: {
                Label("Я ведущий", systemImage: "person.crop.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                viewModel.choose(role: .player)
            } label: {
                Label("Я игрок", systemImage: "person.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("Локальная игра по Wi-Fi без интернета")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    RoleSelectionView(viewModel: AppViewModel())
}

