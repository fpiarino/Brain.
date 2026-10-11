import SwiftData
import UIKit
import UserNotifications

/// Riceve le risposte alle notifiche del promemoria (✓ / ✗ / valore) anche ad app chiusa.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories(ReminderScheduler.categories)
        return true
    }

    /// Mostra il promemoria anche se l'app è aperta.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await NotificationActionHandler.handle(response)
    }
}

@MainActor
enum NotificationActionHandler {

    static func handle(_ response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard
            let idText = info[ReminderScheduler.goalIDKey] as? String,
            let id = UUID(uuidString: idText),
            let dayRaw = info[ReminderScheduler.dayKey] as? Int,
            let day = DayKey(rawValue: dayRaw)
        else { return }

        let context = AppModel.shared.container.mainContext
        guard let goal = context.goal(withID: id) else { return }

        switch response.actionIdentifier {
        case ReminderScheduler.doneAction:
            context.setStatus(.done, for: goal, on: day)
        case ReminderScheduler.missedAction:
            context.setStatus(.missed, for: goal, on: day)
        case ReminderScheduler.valueAction:
            if let text = (response as? UNTextInputNotificationResponse)?.userText,
               let value = GoalRules.parseNumber(text) {
                context.setValue(value, for: goal, on: day)
            }
        case UNNotificationDefaultActionIdentifier:
            AppModel.shared.pendingGoalID = id
        default:
            break
        }
        await ReminderScheduler.reschedule(using: context)
    }
}
