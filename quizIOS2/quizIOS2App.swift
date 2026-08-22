//
//  quizIOS2App.swift
//  quizIOS2 — iOS Showcase App
//
//  Демонстрация азов и возможностей iOS-разработки на Swift + SwiftUI
//

import SwiftUI

@main
struct quizIOS2App: App {
    init() {
        LocalNetworkDiagnostics.logConfigurationOnLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Проверяет при запуске, что в собранный Info.plist действительно попали ключи,
/// необходимые для системного запроса разрешения "Локальная сеть" (Bonjour/mDNS).
/// Если билд собран без них (например, из-за проблемы с build settings или
/// сторонней схемой сборки), permission-алерт у iOS никогда не появится,
/// а приложение даже не будет числиться в Настройки → Локальная сеть.
enum LocalNetworkDiagnostics {
    static func logConfigurationOnLaunch() {
        let info = Bundle.main.infoDictionary

        let bonjourServices = info?["NSBonjourServices"] as? [String]
        let usageDescription = info?["NSLocalNetworkUsageDescription"] as? String

        print("——— [LocalNetwork] Проверка конфигурации при запуске ———")

        if let bonjourServices, !bonjourServices.isEmpty {
            print("——— [LocalNetwork] NSBonjourServices: \(bonjourServices) ✅")
        } else {
            print("——— [LocalNetwork] NSBonjourServices ОТСУТСТВУЕТ в Info.plist ❌")
            print("——— [LocalNetwork] Разрешение на локальную сеть НЕ будет запрошено iOS.")
            print("——— [LocalNetwork] Проверьте: Target → Build Settings → \"Bonjour\", ключ INFOPLIST_KEY_NSBonjourServices.")
        }

        if let usageDescription, !usageDescription.isEmpty {
            print("——— [LocalNetwork] NSLocalNetworkUsageDescription: \"\(usageDescription)\" ✅")
        } else {
            print("——— [LocalNetwork] NSLocalNetworkUsageDescription ОТСУТСТВУЕТ в Info.plist ❌")
            print("——— [LocalNetwork] Без этого ключа iOS тоже не покажет системный алерт.")
        }

        if bonjourServices?.contains(NetworkManager.serviceType) != true {
            print("——— [LocalNetwork] ВНИМАНИЕ: тип сервиса в коде — \"\(NetworkManager.serviceType)\", он отсутствует в NSBonjourServices выше. Значения должны совпадать дословно.")
        }

        print("——— [LocalNetwork] Bundle ID: \(Bundle.main.bundleIdentifier ?? "неизвестен")")
        print("——— [LocalNetwork] Если ключи выше ✅, но алерт всё равно не появляется — удалите приложение с устройства, перезагрузите телефон и установите заново.")
        print("————————————————————————————————————————————————")
    }
}