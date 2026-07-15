//
//  ContentView.swift
//  quizIOS2
//
//  Корневой роутер экранов приложения "Я Знаю".
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .splash:
                    SplashView()

                case .roleSelection:
                    RoleSelectionView(viewModel: viewModel)

                case .hostLobby:
                    HostLobbyView(viewModel: viewModel)

                case .hostControl:
                    HostControlView(viewModel: viewModel)

                case .playerJoin:
                    PlayerJoinView(viewModel: viewModel)

                case .playerWaiting:
                    PlayerWaitingView(viewModel: viewModel)

                case .playerQuestion:
                    GameView(viewModel: viewModel)
                }
            }
        }
        .onAppear {
            viewModel.bootSplash()
        }
    }
}

#Preview {
    ContentView()
}
