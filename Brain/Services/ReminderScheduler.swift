import Foundation
import SwiftData
import UserNotifications

/// Impostazioni del promemoria, salvate in UserDefaults (usate anche da `@AppStorage`).
enum ReminderSettings {
    static let enabledKey = "reminderEnabled"
    static let hourKey = "reminderHour"
    static let minuteKey = "reminderMinute"
    static let defaultHour = 21
    static let defaultMinute = 0

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var hour: Int {
        UserDefaults.standard.object(forKey: hourKey) as? Int ?? defaultHour
    }

    static var minute: Int {
        UserDefaults.standard.object(forKey: minuteKey) as? Int ?? defaultMinute
    }
}

/// Pianifica il promemoria serale: una notifica per obiettivo, con i pulsanti per
/// rispondere senza aprire l'app (✓ / ✗, oppure il valore per i numerici).
///
/// Il piano copre i prossimi giorni (al massimo 14, entro il limite di iOS di 64 notifiche)
/// e viene ricalcolato quando apri o chiudi l'app e dopo ogni risposta a una notifica.
/// Quello di oggi parte solo per gli obiettivi ancora da registrare.
enum ReminderScheduler {
    static let identifierPrefix = "brain.reminder."
    static let goalIDKey = "goalID"
    static let dayKey = "day"

    static let doneAction = "brain.action.done"
    static let missedAction = "brain.action.missed"
    static let valueAction = "brain.action.value"

    static let dailyCategory = "brain.category.daily"
    static let weeklyCategory = "brain.category.weekly"
    static let numericCategory = "brain.category.numeric"

    static var categories: Set<UNNotificationCategory> {
        let done = UNNotificationAction(identifier: doneAction, title: "✓ Fatto", options: [])
        let missed = UNNotificationAction(identifier: missedAction, title: "✗ Non fatto", options: [])
        let value = UNTextInputNotificationAction(
            identifier: valueAction,
            title: "Inserisci il valore",
            options: [],
            textInputButtonTitle: "Salva",
            textInputPlaceholder: "Es. 1650"
        )
        return [
            UNNotificationCategory(identifier: dailyCategory, actions: [done, missed], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: weeklyCategory, actions: [done], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: numericCategory, actions: [value], intentIdentifiers: [], options: [])
        ]
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Chiede il permesso di inviare notifiche. Restituisce `true` se concesso.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    @MainActor
    static func reschedule(using context: ModelContext) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard ReminderSettings.isEnabled, !SharedStore.isUITesting else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        // Gli obiettivi collegati ad Apple Salute si compilano da soli: niente promemoria.
        let goals = context.activeGoals().filter { !$0.isHealthLinked }
        guard !goals.isEmpty else { return }

        let calendar = Calendar.brain
        let now = Date()
        let today = DayKey(now, calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minutesNow = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let hour = ReminderSettings.hour
        let minute = ReminderSettings.minute

        let pendingToday = goals.filter { $0.needsRegistration(today: today) }
        let days = ReminderPlanner.days(
            today: today,
            minutesNow: minutesNow,
            reminderMinutes: hour * 60 + minute,
            hasPendingToday: !pendingToday.isEmpty,
            horizon: ReminderPlanner.horizon(goalsPerDay: goals.count)
        )

        for day in days {
            let goalsForDay = day == today ? pendingToday : goals.filter { $0.startDay <= day }
            for goal in goalsForDay {
                let request = UNNotificationRequest(
                    identifier: "\(identifierPrefix)\(day.rawValue).\(goal.id.uuidString)",
                    content: content(for: goal, day: day, isToday: day == today),
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: DateComponents(calendar: calendar, year: day.year, month: day.month, day: day.day, hour: hour, minute: minute),
                        repeats: false
                    )
                )
                try? await center.add(request)
            }
        }
    }

    @MainActor
    private static func content(for goal: Goal, day: DayKey, isToday: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(goal.emoji) \(goal.name)"
        content.sound = .default
        content.threadIdentifier = "\(identifierPrefix)\(day.rawValue)"
        content.userInfo = [goalIDKey: goal.id.uuidString, dayKey: day.rawValue]

        switch goal.kind {
        case .daily:
            content.categoryIdentifier = dailyCategory
            content.body = "Com'è andata oggi?"
        case .weekly:
            content.categoryIdentifier = weeklyCategory
            if isToday {
                let week = goal.currentWeek(today: day)
                content.body = "L'hai fatto oggi? Questa settimana: \(week.done) di \(week.target)."
            } else {
                content.body = "L'hai fatto oggi?"
            }
        case .numeric:
            content.categoryIdentifier = numericCategory
            content.body = "Inserisci il valore di oggi (obiettivo \(goal.targetDescription))."
        }
        return content
    }
}
