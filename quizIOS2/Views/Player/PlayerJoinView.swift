import SwiftUI

struct PlayerJoinView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var manualHostText = ""
    @State private var showScanner = false

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
                                if !server.details.isEmpty {
                                    Text(server.details)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Не нашли хоста в списке?")
                    .font(.headline)
                Text("Автопоиск не всегда работает (например, в сети хотспота) — отсканируйте QR-код с экрана ведущего или введите его IP-адрес вручную")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showScanner = true
                } label: {
                    Label("Сканировать QR-код", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                TextField("IP:порт (например 192.168.1.5:5000)", text: $manualHostText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)

                Button("Подключиться по IP") {
                    viewModel.connectAsPlayerManual(manualHostText)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(manualHostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

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
        .sheet(isPresented: $showScanner) {
            QRScannerSheet { scanned in
                manualHostText = scanned
                showScanner = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlayerJoinView(viewModel: AppViewModel())
    }
}
