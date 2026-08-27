import AudioToolbox
import UIKit

/// Короткая вибрация + системный звук-тик при нажатии игровых кнопок (Открыть/Закрыть
/// раунд, Ответ верный/неверный, Сбросить счёт) — по аналогии с реализацией на Android
/// (см. FeedbackUtils.kt). Кнопка "Ответить" в GameView уже имела свой haptic-генератор
/// (heavy-стиль) — туда просто добавлен тот же системный звук для единообразия.
enum ButtonFeedback {
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    static func trigger() {
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        AudioServicesPlaySystemSound(1057)
    }
}
