//
//  NavigationDemoView.swift
//  quizIOS2
//
//  Демонстрация навигации в SwiftUI:
//  NavigationStack, NavigationLink, .sheet, .fullScreenCover, .alert, .confirmationDialog,
//  а также макеты: VStack, HStack, ZStack, LazyVGrid, ScrollView.
//

import SwiftUI

struct NavigationDemoView: View {
    @State private var showSheet         = false
    @State private var showFullScreen    = false
    @State private var showAlert         = false
    @State private var showConfirm       = false
    @State private var alertMessage      = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                NavigationSection(
                    showSheet: $showSheet,
                    showFullScreen: $showFullScreen,
                    showAlert: $showAlert,
                    showConfirm: $showConfirm,
                    alertMessage: $alertMessage
                )
                LayoutSection()
            }
            .padding()
        }
        .navigationTitle("Навигация и макеты")
        .navigationBarTitleDisplayMode(.large)
        // ── Sheet ──────────────────────────────────────────────────────────
        .sheet(isPresented: $showSheet) {
            SheetView()
        }
        // ── Full Screen Cover ──────────────────────────────────────────────
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenView()
        }
        // ── Alert ──────────────────────────────────────────────────────────
        .alert("Уведомление", isPresented: $showAlert) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        // ── Confirmation Dialog ────────────────────────────────────────────
        .confirmationDialog("Что сделать?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Сохранить")    {}
            Button("Поделиться")   {}
            Button("Удалить", role: .destructive) {}
            Button("Отмена", role: .cancel) {}
        }
    }
}

// MARK: - Навигация

struct NavigationSection: View {
    @Binding var showSheet: Bool
    @Binding var showFullScreen: Bool
    @Binding var showAlert: Bool
    @Binding var showConfirm: Bool
    @Binding var alertMessage: String

    let pages = ["Первая страница", "Вторая страница", "Третья страница"]

    var body: some View {
        VStack(spacing: 16) {
            Text("🧭 Навигация").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)

            // NavigationLink
            GroupBox(label: Label("NavigationStack + NavigationLink", systemImage: "arrow.right.square")) {
                VStack(spacing: 0) {
                    ForEach(pages, id: \.self) { page in
                        NavigationLink(destination: DetailPageView(title: page)) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.blue)
                                Text(page)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if page != pages.last {
                            Divider()
                        }
                    }
                }
            }

            // Модальные окна
            GroupBox(label: Label("Модальные представления", systemImage: "macwindow")) {
                VStack(spacing: 10) {
                    Button("Открыть .sheet (снизу)") { showSheet = true }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                    Button("Открыть .fullScreenCover") { showFullScreen = true }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            }

            // Диалоги
            GroupBox(label: Label("Alert и ConfirmationDialog", systemImage: "exclamationmark.triangle")) {
                VStack(spacing: 10) {
                    Button("Показать Alert") {
                        alertMessage = "Это пример Alert в SwiftUI. Работает как нативный диалог iOS."
                        showAlert = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Показать Action Sheet") { showConfirm = true }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Макеты

struct LayoutSection: View {
    let gridItems = ["🍎", "🍊", "🍋", "🍇", "🍓", "🫐", "🍑", "🥝", "🍉"]

    var body: some View {
        VStack(spacing: 16) {
            Text("📐 Макеты").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)

            // VStack
            GroupBox(label: Label("VStack — вертикальный стек", systemImage: "arrow.down")) {
                VStack(spacing: 6) {
                    ForEach(["Первый", "Второй", "Третий"], id: \.self) { item in
                        Text(item)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // HStack
            GroupBox(label: Label("HStack — горизонтальный стек", systemImage: "arrow.right")) {
                HStack(spacing: 8) {
                    ForEach(["A", "B", "C", "D"], id: \.self) { item in
                        Text(item)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // ZStack
            GroupBox(label: Label("ZStack — наложение слоёв", systemImage: "square.3.layers.3d")) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.indigo.opacity(0.3))
                        .frame(height: 80)

                    Circle()
                        .fill(.purple.opacity(0.5))
                        .frame(width: 60)

                    Text("ZStack")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }

            // LazyVGrid
            GroupBox(label: Label("LazyVGrid — сетка", systemImage: "square.grid.3x3")) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(gridItems, id: \.self) { emoji in
                        Text(emoji)
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // ScrollView
            GroupBox(label: Label("ScrollView — горизонтальный скролл", systemImage: "scroll")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<10) { i in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill([Color.blue, .orange, .green, .purple, .red][i % 5].gradient)
                                    .frame(width: 52, height: 52)
                                Text("Элемент \(i + 1)")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Spacer
            GroupBox(label: Label("Spacer и выравнивание", systemImage: "arrow.left.and.right")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Слева")
                        Spacer()
                        Text("По центру")
                        Spacer()
                        Text("Справа")
                    }

                    HStack {
                        Text("Начало").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Конец").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Дополнительные представления

struct DetailPageView: View {
    let title: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)

            Text(title)
                .font(.title.bold())

            Text("Это детальная страница, открытая через NavigationLink.\nSwiftUI управляет навигационным стеком автоматически.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 40)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "arrow.up.to.line.compact")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple.gradient)

                Text(".sheet")
                    .font(.largeTitle.bold())

                Text("Частичный экран снизу.\nМожно смахнуть вниз или нажать «Закрыть».")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

struct FullScreenView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple, .pink],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "rectangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)

                Text(".fullScreenCover")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Занимает весь экран.\nНельзя смахнуть — только программное закрытие.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))

                Button("Закрыть") { dismiss() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .padding(.top, 20)
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        NavigationDemoView()
    }
}

