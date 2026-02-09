import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            if granted {
                print("Notification authorization granted")
            }
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    func notifyQueueCompleted(totalCount: Int, successCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "VideoHelper"
        content.body = "Обработано \(successCount) из \(totalCount) видео"
        content.sound = .default
        content.categoryIdentifier = "QUEUE_COMPLETED"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
}
