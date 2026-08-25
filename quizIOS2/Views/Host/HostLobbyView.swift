import SwiftUI

private enum HostLobbySheet: String, Identifiable {
    case rules
    case settings

    var id: String { rawValue }
}

struct HostLobbyView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var activeSheet: HostLobbySheet?
    @State private var showQRSheet = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    activeSheet = .rules
                } label: {
                    Label("Правила", systemImage: "list.bullet.clipboard")
                }
                .buttonStyle(.bordered)
                Button {
                    activeSheet = .settings
                } label: {
                    Label("Настройки", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
            }

            TextField("Имя ведущего", text: $viewModel.hostNickname)
            .textFieldStyle(.roundedBorder)

            Button(startButtonTitle) {
                viewModel.startHosting()
            }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.network.status == .connecting)

            if let ip = viewModel.hostLocalIp {
                Button {
                    showQRSheet = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Скажите игрокам подключиться по IP (нажмите для QR-кода):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(ip):\(viewModel.hostPortText)")
                            .font(.title3.bold())
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

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
                    .disabled(viewModel.players.isEmpty || viewModel.network.status != .connected)

            Text(startGameHint)
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
                .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings:
                HostSettingsSheet(viewModel: viewModel)
            case .rules:
                HostRulesSheet()
            }
        }
                .sheet(isPresented: $showQRSheet) {
            QRCodeSheet(text: "\(viewModel.hostLocalIp ?? "")" + ":" + viewModel.hostPortText)
        }
    }

    /// Сервер теперь запускается только по явному нажатию — до этого момента ведущий
    /// может спокойно поменять имя и порт в настройках, не поднимая слушатель раньше времени.
    private var startButtonTitle: String {
        switch viewModel.network.status {
        case .connected: return "Перезапустить сервер"
        case .connecting: return "Запуск..."
        case .failed: return "Повторить запуск"
        case .disconnected: return "Запустить сервер"
        }
    }

    private var startGameHint: String {
        if viewModel.network.status != .connected {
            return "Сначала запустите сервер кнопкой выше"
        }
        return viewModel.players.isEmpty ? "Подключите хотя бы 1 игрока для старта" : "Можно начинать игру"
    }

    private var statusText: String {
        switch viewModel.network.status {
        case .connected: return "Сервер активен"
        case .connecting: return "Запуск..."
        case .disconnected: return "Сервер не запущен"
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

private struct HostRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Как проходит раунд")
                    .font(.title3.bold())

                    RuleRow(number: "1", text: "Ведущий задаёт вопрос устно или читает его из внешнего источника.")
                    RuleRow(number: "2", text: "Ведущий нажимает «Открыть раунд».")
                    RuleRow(number: "3", text: "Игроки нажимают кнопку «Ответить». Засчитывается только первое нажатие.")
                    RuleRow(number: "4", text: "Ведущий видит, кто ответил первым, и принимает решение.")
                    RuleRow(number: "5", text: "Если ответ неверный — раунд продолжается, но этот игрок повторно нажать уже не может.")
                    RuleRow(number: "6", text: "Если ответ верный — игрок получает 1 очко, а раунд закрывается.")
                }
                .padding()
            }
                    .navigationTitle("Правила")
                    .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

private struct QRCodeSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Отсканируйте камерой на телефоне игрока")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let image = QRCode.generateImage(from: text) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 240, height: 240)
                } else {
                    Text("Не удалось построить QR-код")
                        .foregroundStyle(.secondary)
                }

                Text(text)
                    .font(.headline)
            }
            .padding()
            .navigationTitle("QR-код")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

private struct RuleRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.blue, in: Circle())

            Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        HostLobbyView(viewModel: AppViewModel())
    }
}