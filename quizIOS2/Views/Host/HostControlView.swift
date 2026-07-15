import SwiftUI

struct HostControlView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var category = "Музыка и поп-культура"
    @State private var questionText = ""
    @State private var optionA = ""
    @State private var optionB = ""
    @State private var optionC = ""
    @State private var optionD = ""
    @State private var correctIndex = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Панель ведущего")
                    .font(.title2.bold())

                Text("Вопросы хранятся и вводятся только у ведущего")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Категория", text: $category)
                    .textFieldStyle(.roundedBorder)

                TextField("Текст вопроса", text: $questionText, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                Group {
                    TextField("Вариант A", text: $optionA)
                    TextField("Вариант B", text: $optionB)
                    TextField("Вариант C", text: $optionC)
                    TextField("Вариант D", text: $optionD)
                }
                .textFieldStyle(.roundedBorder)

                Picker("Правильный ответ", selection: $correctIndex) {
                    Text("A").tag(0)
                    Text("B").tag(1)
                    Text("C").tag(2)
                    Text("D").tag(3)
                }
                .pickerStyle(.segmented)

                Button("Отправить вопрос игрокам") {
                    viewModel.sendQuestionFromHost(
                        category: category,
                        text: questionText,
                        options: [optionA, optionB, optionC, optionD],
                        correctIndex: correctIndex
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Divider()

                Text("Получено ответов: \(viewModel.hostReceivedAnswers.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(viewModel.hostReceivedAnswers.enumerated()), id: \.offset) { _, answer in
                    HStack {
                        Text(answer.playerID.uuidString.prefix(6))
                        Spacer()
                        Text(["A", "B", "C", "D"][min(max(answer.selectedIndex, 0), 3)])
                            .bold()
                    }
                }

                Button("Разослать результаты") {
                    viewModel.evaluateAnswersAsHost()
                }
                .buttonStyle(.bordered)

                Button("Завершить и выйти") {
                    viewModel.resetToRoleSelection()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Управление игрой")
    }
}

#Preview {
    NavigationStack {
        HostControlView(viewModel: AppViewModel())
    }
}

