//
//  AnimationsAndGesturesView.swift
//  quizIOS2
//
//  Демонстрация анимаций и жестов SwiftUI.
//

import SwiftUI

struct AnimationsAndGesturesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AnimationsSection()
                GesturesSection()
            }
            .padding()
        }
        .navigationTitle("Анимации и жесты")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Анимации

struct AnimationsSection: View {
    @State private var isScaled     = false
    @State private var isRotated    = false
    @State private var isMoving     = false
    @State private var isBouncing   = false
    @State private var showCard     = true
    @State private var colorPhase   = false

    var body: some View {
        VStack(spacing: 20) {
            Text("✨ Анимации").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)

            // 1. Масштабирование
            GroupBox(label: Label("withAnimation(.spring)", systemImage: "arrow.up.left.and.arrow.down.right")) {
                HStack(spacing: 20) {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: isScaled ? 80 : 40, height: isScaled ? 80 : 40)
                        .animation(.spring(response: 0.5, dampingFraction: 0.4), value: isScaled)

                    Button(isScaled ? "Уменьшить" : "Увеличить") {
                        isScaled.toggle()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }

            // 2. Вращение
            GroupBox(label: Label("rotationEffect", systemImage: "rotate.right")) {
                HStack(spacing: 20) {
                    Image(systemName: "gear.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(isRotated ? 180 : 0))
                        .animation(.easeInOut(duration: 0.6), value: isRotated)

                    Button("Повернуть") {
                        isRotated.toggle()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }

            // 3. Переход — появление/исчезание
            GroupBox(label: Label("transition(.slide)", systemImage: "arrow.left.arrow.right")) {
                VStack(spacing: 10) {
                    Button(showCard ? "Скрыть" : "Показать") {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showCard.toggle()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if showCard {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.purple, .pink],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(height: 60)
                            .overlay(Text("Привет, SwiftUI!").foregroundStyle(.white).bold())
                            .transition(.asymmetric(insertion: .slide, removal: .opacity))
                    }
                }
            }

            // 4. Цвет с анимацией
            GroupBox(label: Label("Анимация цвета", systemImage: "paintpalette")) {
                HStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorPhase ? Color.green : Color.blue)
                        .frame(height: 50)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                   value: colorPhase)
                        .onAppear { colorPhase = true }

                    Text("Пульс")
                        .scaleEffect(colorPhase ? 1.2 : 0.9)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                   value: colorPhase)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Жесты

struct GesturesSection: View {
    @State private var tapCount      = 0
    @State private var longPressed   = false
    @State private var dragOffset    = CGSize.zero
    @State private var magnifyScale  = 1.0
    @State private var rotateAngle   = Angle.zero

    var body: some View {
        VStack(spacing: 20) {
            Text("👆 Жесты").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)

            // 1. Tap
            GroupBox(label: Label("TapGesture", systemImage: "hand.tap")) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(Text("\(tapCount)").foregroundStyle(.white).font(.title.bold()))
                        .onTapGesture { tapCount += 1 }
                        .onLongPressGesture { tapCount = 0 }

                    Text("Нажми для счёта • Зажми для сброса")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // 2. Drag
            GroupBox(label: Label("DragGesture", systemImage: "arrow.up.and.down.and.arrow.left.and.right")) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.gray.opacity(0.15))
                            .frame(height: 150)

                        Circle()
                            .fill(.orange.gradient)
                            .frame(width: 50, height: 50)
                            .offset(dragOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring()) {
                                            dragOffset = .zero
                                        }
                                    }
                            )
                    }
                    Text("Перетащи кружок (отпусти — вернётся)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // 3. Magnify (Pinch)
            GroupBox(label: Label("MagnifyGesture (Pinch)", systemImage: "plus.magnifyingglass")) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.teal)
                        .scaleEffect(magnifyScale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    magnifyScale = max(0.5, min(3.0, value.magnification))
                                }
                                .onEnded { _ in
                                    withAnimation(.spring()) {
                                        magnifyScale = 1.0
                                    }
                                }
                        )

                    Text("Сведи/разведи пальцы для масштаба")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // 4. Rotate
            GroupBox(label: Label("RotateGesture", systemImage: "crop.rotate")) {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                        .rotationEffect(rotateAngle)
                        .gesture(
                            RotateGesture()
                                .onChanged { value in rotateAngle = value.rotation }
                                .onEnded { _ in
                                    withAnimation(.spring()) { rotateAngle = .zero }
                                }
                        )

                    Text("Поверни двумя пальцами")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AnimationsAndGesturesView()
    }
}

