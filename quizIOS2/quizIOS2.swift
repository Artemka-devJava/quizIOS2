//
//  quizIOS2.swift
//  quizIOS2
//
//  Вспомогательные модели и типы данных приложения.
//

import Foundation
import SwiftUI

// MARK: - Модели данных

/// Раздел-демонстрация iOS-возможностей
struct ShowcaseSection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

/// Элемент списка жестов
struct GestureItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
}

/// Пример анимации
struct AnimationExample: Identifiable {
    let id = UUID()
    let name: String
    let description: String
}

// MARK: - Данные для демонстрации

extension ShowcaseSection {
    static let all: [ShowcaseSection] = [
        ShowcaseSection(title: "UI-компоненты",    subtitle: "Text, Button, Image, Shape",   icon: "rectangle.3.group.fill",  color: .blue),
        ShowcaseSection(title: "Макеты",           subtitle: "Stack, Grid, ScrollView",       icon: "square.grid.3x3.fill",    color: .indigo),
        ShowcaseSection(title: "Анимации",         subtitle: "Spring, Ease, Transition",      icon: "sparkles",                color: .purple),
        ShowcaseSection(title: "Жесты",            subtitle: "Tap, Drag, Pinch, Swipe",       icon: "hand.tap.fill",           color: .orange),
        ShowcaseSection(title: "Состояние",        subtitle: "@State, @Binding, @Observable", icon: "arrow.triangle.2.circlepath", color: .green),
        ShowcaseSection(title: "Списки",           subtitle: "List, ForEach, Search",         icon: "list.bullet.rectangle",  color: .teal),
        ShowcaseSection(title: "Навигация",        subtitle: "NavigationStack, Sheet, Alert", icon: "arrow.right.square.fill", color: .red),
        ShowcaseSection(title: "Хранение данных",  subtitle: "UserDefaults, @AppStorage",     icon: "externaldrive.fill",      color: .brown),
    ]
}
