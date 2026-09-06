import Foundation
import UserNotifications

/// Gestor de notificaciones locales de macOS para eventos de hardware críticos.
public final class NotificationManager {
    public static let shared = NotificationManager()

    private var activeAlertKeys = Set<String>()

    private init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("TankControl: Error solicitando permisos de notificación: %@", error.localizedDescription)
            }
        }
    }

    public func notifyOnce(key: String, title: String, body: String) {
        guard !activeAlertKeys.contains(key) else { return }
        activeAlertKeys.insert(key)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if let error = error {
                NSLog("TankControl: No se pudo entregar notificación: %@", error.localizedDescription)
            }
        }
    }

    public func clearKey(_ key: String) {
        activeAlertKeys.remove(key)
    }

    public func clearAll() {
        activeAlertKeys.removeAll()
    }
}
