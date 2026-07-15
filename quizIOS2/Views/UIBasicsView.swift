//
//  UIBasicsView.swift
//  quizIOS2
//
//  Демонстрация базовых UI-компонентов SwiftUI:
//  Text, Button, Image, Shape, Color, TextField, Toggle, Slider, Picker.
//

import SwiftUI

struct UIBasicsView: View {
    // @State — хранит локальное состояние компонента
    @State private var sliderValue: Double = 0.5
    @State private var toggleOn: Bool = true
    @State private var textInput: String = ""
    @State private var selectedColor: String = "Синий"
    @State private var buttonTaps: Int = 0

    let colorOptions = ["Синий", "Зелёный", "Оранжевый", "Красный"]

    var pickedColor: Color {
        switch selectedColor {
        case "Зелёный":  return .green
        case "Оранжевый": return .orange
        case "Красный":  return .red
        default:         return .blue
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Text ──────────────────────────────────────────────────
                GroupBox(label: Label("Text — Текст", systemImage: "textformat")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Большой заголовок").font(.largeTitle)
                        Text("Подзаголовок").font(.title2).foregroundStyle(.blue)
                        Text("Тело текста").font(.body)
                        Text("Подпись").font(.caption).foregroundStyle(.secondary)
                        Text("**Жирный** и *курсив*")
                        Text("Подчёркнутый")
                            .underline()
                            .foregroundStyle(.purple)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // ── Button ────────────────────────────────────────────────
                GroupBox(label: Label("Button — Кнопки", systemImage: "cursorarrow.click")) {
                    VStack(spacing: 10) {
                        Button("Нажми меня (нажато: \(buttonTaps))") {
                            buttonTaps += 1
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Обводка") {}
                            .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            buttonTaps = 0
                        } label: {
                            Label("Сбросить", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ── TextField / SecureField ───────────────────────────────
                GroupBox(label: Label("TextField — Ввод", systemImage: "keyboard")) {
                    VStack(spacing: 10) {
                        TextField("Введите текст...", text: $textInput)
                            .textFieldStyle(.roundedBorder)

                        if !textInput.isEmpty {
                            Text("Вы ввели: \"\(textInput)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        SecureField("Пароль", text: .constant(""))
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // ── Toggle / Slider ───────────────────────────────────────
                GroupBox(label: Label("Toggle & Slider", systemImage: "switch.2")) {
                    VStack(spacing: 12) {
                        Toggle("Уведомления включены", isOn: $toggleOn)

                        VStack(alignment: .leading) {
                            Text("Громкость: \(Int(sliderValue * 100))%")
                                .font(.subheadline)
                            Slider(value: $sliderValue, in: 0...1)
                                .accentColor(.blue)
                        }
                    }
                }

                // ── Picker ────────────────────────────────────────────────
                GroupBox(label: Label("Picker — Выбор", systemImage: "checklist")) {
                    VStack(spacing: 10) {
                        Picker("Цвет", selection: $selectedColor) {
                            ForEach(colorOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)

                        RoundedRectangle(cornerRadius: 12)
                            .fill(pickedColor)
                            .frame(height: 44)
                            .animation(.easeInOut, value: selectedColor)
                    }
                }

                // ── Shapes & Colors ───────────────────────────────────────
                GroupBox(label: Label("Shape — Фигуры", systemImage: "square.on.circle")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        Circle()
                            .fill(.blue)
                            .frame(height: 56)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(.orange)
                            .frame(height: 56)

                        Capsule()
                            .fill(.green)
                            .frame(height: 56)

                        Ellipse()
                            .fill(.purple)
                            .frame(height: 56)

                        // Градиент
                        Circle()
                            .fill(
                                LinearGradient(colors: [.red, .yellow],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: 56)

                        // Обводка
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.teal, lineWidth: 3)
                            .frame(height: 56)

                        // Тень
                        Circle()
                            .fill(.white)
                            .frame(height: 56)
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)

                        // SF Symbol
                        Image(systemName: "star.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.yellow)
                    }
                }

            }
            .padding()
        }
        .navigationTitle("UI-компоненты")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        UIBasicsView()
    }
}

