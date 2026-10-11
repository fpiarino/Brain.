import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// Impostazioni del promemoria serale: attivazione e orario.
struct ReminderSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage(ReminderSettings.enabledKey) private var enabled = false
    @AppStorage(ReminderSettings.hourKey) private var hour = ReminderSettings.defaultHour
    @AppStorage(ReminderSettings.minuteKey) private var minute = ReminderSettings.defaultMinute

    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    init() {}

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Promemoria serale", isOn: enabledBinding)
                        .disabled(isRequesting)
                    if enabled {
                        DatePicker("Orario", selection: timeBinding, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("La sera ricevi una notifica per ogni obiettivo ancora da registrare, con i pulsanti per rispondere senza aprire l'app. Gli obiettivi collegati ad Apple Salute non ricevono promemoria. Il piano si aggiorna ogni volta che apri l'app.")
                }

                if authorization == .denied {
                    Section {
                        Text("Le notifiche di Brain sono disattivate nelle Impostazioni di iOS.")
                        Button("Apri Impostazioni") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Promemoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
            .task {
                authorization = await ReminderScheduler.authorizationStatus()
                // Se il permesso è stato tolto dalle Impostazioni, il promemoria risulta spento.
                if authorization == .denied && enabled {
                    enabled = false
                }
            }
            .onChange(of: "\(enabled)-\(hour)-\(minute)") { _, _ in
                Task { await ReminderScheduler.reschedule(using: modelContext) }
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { enabled },
            set: { newValue in
                if newValue {
                    Task { await enable() }
                } else {
                    enabled = false
                }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.brain.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let components = Calendar.brain.dateComponents([.hour, .minute], from: newValue)
                hour = components.hour ?? ReminderSettings.defaultHour
                minute = components.minute ?? ReminderSettings.defaultMinute
            }
        )
    }

    private func enable() async {
        isRequesting = true
        defer { isRequesting = false }

        var status = await ReminderScheduler.authorizationStatus()
        if status == .notDetermined {
            _ = await ReminderScheduler.requestAuthorization()
            status = await ReminderScheduler.authorizationStatus()
        }
        authorization = status
        enabled = status == .authorized || status == .provisional || status == .ephemeral
    }
}

#Preview {
    ReminderSettingsView()
        .modelContainer(for: [Goal.self, DayEntry.self], inMemory: true)
}
