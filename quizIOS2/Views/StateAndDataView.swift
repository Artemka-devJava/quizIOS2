//
//  StateAndDataView.swift
//  quizIOS2
//
//  Демонстрация управления состоянием:
//  @State, @Binding, @StateObject / @ObservedObject, @EnvironmentObject, @AppStorage.
//  А также: List, ForEach, поиск и сортировка.
//

import SwiftUI
import Combine

// MARK: - ViewModel (ObservableObject)

/// Пример класса ViewModel — хранит список задач и логику работы с ним.
@Observable
final class TaskViewModel {
    var tasks: [TaskItem] = [
        TaskItem(title: "Изучить SwiftUI",         done: true),
        TaskItem(title: "Написать первый View",     done: true),
        TaskItem(title: "Разобраться с @State",     done: false),
        TaskItem(title: "Попробовать анимации",     done: false),
        TaskItem(title: "Запустить на симуляторе",  done: false),
    ]
    var searchText: String = ""

    var filtered: [TaskItem] {
        guard !searchText.isEmpty else { return tasks }
        return tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    func toggleDone(task: TaskItem) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].done.toggle()
        }
    }

    func addTask(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        tasks.append(TaskItem(title: title, done: false))
    }

    func delete(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
}

struct TaskItem: Identifiable {
    let id = UUID()
    var title: String
    var done: Bool
}

// MARK: - Главное представление

struct StateAndDataView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StateBindingDemo()
                ObservableDemo()
                AppStorageDemo()
            }
            .padding()
        }
        .navigationTitle("Состояние и данные")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - @State и @Binding

struct StateBindingDemo: View {
    @State private var counter = 0
    @State private var name    = "Swift"

    var body: some View {
        GroupBox(label: Label("@State и @Binding", systemImage: "arrow.triangle.2.circlepath")) {
            VStack(spacing: 14) {
                // @State — простое состояние
                HStack {
                    Button("-") { counter -= 1 }
                        .buttonStyle(.bordered)
                    Text("\(counter)")
                        .font(.title2.monospacedDigit())
                        .frame(width: 60)
                    Button("+") { counter += 1 }
                        .buttonStyle(.borderedProminent)
                }

                Divider()

                // @Binding — передача состояния вниз
                Text("Имя: **\(name)**")
                BindingTextField(text: $name)  // передаём binding
            }
        }
    }
}

/// Дочерний компонент, принимающий @Binding
struct BindingTextField: View {
    @Binding var text: String  // ← @Binding позволяет изменять состояние родителя

    var body: some View {
        HStack {
            Image(systemName: "pencil")
                .foregroundStyle(.blue)
            TextField("Введите имя", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - @Observable (iOS 17+)

struct ObservableDemo: View {
    @State private var viewModel = TaskViewModel()
    @State private var newTaskTitle = ""

    var body: some View {
        GroupBox(label: Label("@Observable + List", systemImage: "list.bullet.rectangle")) {
            VStack(spacing: 12) {
                // Добавление задачи
                HStack {
                    TextField("Новая задача...", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)
                    Button("Добавить") {
                        viewModel.addTask(newTaskTitle)
                        newTaskTitle = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTaskTitle.isEmpty)
                }

                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Поиск...", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                }

                // Список
                VStack(spacing: 0) {
                    ForEach(viewModel.filtered) { task in
                        HStack {
                            Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.done ? .green : .secondary)
                                .font(.title3)
                            Text(task.title)
                                .strikethrough(task.done, color: .secondary)
                                .foregroundStyle(task.done ? .secondary : .primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.toggleDone(task: task) }

                        if task.id != viewModel.filtered.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 4)

                Text("Выполнено: \(viewModel.tasks.filter(\.done).count) / \(viewModel.tasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - @AppStorage

struct AppStorageDemo: View {
    // @AppStorage сохраняет значение в UserDefaults автоматически
    @AppStorage("userName")     private var userName    = "Пользователь"
    @AppStorage("isDarkMode")   private var isDarkMode  = false
    @AppStorage("launchCount")  private var launchCount = 0

    @State private var editName = ""

    var body: some View {
        GroupBox(label: Label("@AppStorage (UserDefaults)", systemImage: "externaldrive.fill")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Данные сохраняются между запусками приложения")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Имя пользователя", text: $userName)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Тёмная тема", isOn: $isDarkMode)

                Button("Увеличить счётчик запусков") {
                    launchCount += 1
                }
                .buttonStyle(.bordered)

                HStack {
                    Text("Запусков: ")
                    Text("\(launchCount)").bold().foregroundStyle(.blue)
                }

                Text("⚡ Все изменения сохраняются мгновенно в UserDefaults")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StateAndDataView()
    }
}

