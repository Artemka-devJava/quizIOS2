//
//  ContentView.swift
//  quizIOS2
//
//  Корневое представление приложения — TabView с 5 разделами.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Вкладка 1: Главная
            HomeView()
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
                }

            // Вкладка 2: UI-компоненты и Макеты
            NavigationStack {
                UIBasicsView()
            }
            .tabItem {
                Label("UI", systemImage: "rectangle.3.group.fill")
            }

            // Вкладка 3: Анимации и Жесты
            NavigationStack {
                AnimationsAndGesturesView()
            }
            .tabItem {
                Label("Анимации", systemImage: "sparkles")
            }

            // Вкладка 4: Состояние и данные
            NavigationStack {
                StateAndDataView()
            }
            .tabItem {
                Label("Данные", systemImage: "cylinder.split.1x2.fill")
            }

            // Вкладка 5: Навигация и хранение
            NavigationStack {
                NavigationDemoView()
            }
            .tabItem {
                Label("Навигация", systemImage: "arrow.right.square.fill")
            }
        }
    }
}

#Preview {
    ContentView()
}

