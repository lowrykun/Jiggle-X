import SwiftUI

/// Working days, hours, Launch at Login and the idle threshold. Changes apply
/// immediately; an invalid time range is shown but never saved.
struct SettingsView: View {
    /// Called after a valid schedule is saved, so the run state can be re-evaluated.
    var onScheduleChange: () -> Void

    @State private var schedule = PersistenceManager.shared.schedule
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        Form {
            Section("Working Days") {
                HStack {
                    ForEach(orderedWeekdays, id: \.self) { day in
                        Toggle(calendar.shortWeekdaySymbols[day.rawValue - 1], isOn: dayBinding(day))
                            .toggleStyle(.button)
                    }
                }
            }

            Section("Working Hours") {
                DatePicker("Start", selection: timeBinding(\.start), displayedComponents: .hourAndMinute)
                DatePicker("End", selection: timeBinding(\.end), displayedComponents: .hourAndMinute)
                if !schedule.isValid {
                    Text("End time must be after start time.")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section("Advanced") {
                Stepper(value: $schedule.idleThreshold, in: Schedule.idleThresholdRange, step: 30) {
                    Text("Keep active after \(idleThresholdText) idle")
                }
                Text("Teams marks you Away after about 5 minutes, so keep this below that.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: schedule) { newValue in
            guard newValue.isValid else { return }
            PersistenceManager.shared.schedule = newValue
            onScheduleChange()
        }
        .onChange(of: launchAtLogin) { newValue in
            guard newValue != LaunchAtLogin.isEnabled else { return }
            do {
                try LaunchAtLogin.set(newValue)
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = String(localized: "Couldn't update the login item: \(error.localizedDescription)")
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }

    /// Weekdays starting from the user's locale's first day of the week.
    private var orderedWeekdays: [Weekday] {
        (0..<7).map { Weekday(rawValue: (calendar.firstWeekday - 1 + $0) % 7 + 1)! }
    }

    private var idleThresholdText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .short
        return formatter.string(from: schedule.idleThreshold) ?? ""
    }

    private func dayBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { schedule.days.contains(day) },
            set: { isOn in
                if isOn { schedule.days.insert(day) } else { schedule.days.remove(day) }
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<Schedule, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                let time = schedule[keyPath: keyPath]
                return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                schedule[keyPath: keyPath] = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            }
        )
    }
}
