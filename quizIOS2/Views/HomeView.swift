//
//  HomeView.swift
//  quizIOS2
//
//  Главный экран — обзор всех разделов приложения.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero-секция
                    VStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.system(size: 72))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .purple],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)
                            )
                            .symbolEffect(.pulse)

                        Text("iOS Showcase")
                            .font(.largeTitle.bold())

                        Text("Азы и возможности iOS-разработки\nна Swift + SwiftUI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Сетка разделов
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(ShowcaseSection.all) { section in
                            SectionCard(section: section)
                        }
                    }
                    .padding(.horizontal)

                    // Информация о стеке
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Технологический стек")
                            .font(.headline)

                        TechRow(icon: "swift",        title: "Swift 5",         subtitle: "Основной язык")
                        TechRow(icon: "rectangle.3.group", title: "SwiftUI",    subtitle: "Декларативный UI")
                        TechRow(icon: "cpu",          title: "Combine / async", subtitle: "Асинхронность")
                        TechRow(icon: "externaldrive",title: "Foundation",      subtitle: "Базовый фреймворк")
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("iOS Showcase")
        }
    }
}

// MARK: - Вспомогательные компоненты

struct SectionCard: View {
    let section: ShowcaseSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: section.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(section.color, in: RoundedRectangle(cornerRadius: 10))

            Text(section.title)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text(section.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TechRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HomeView()
}

