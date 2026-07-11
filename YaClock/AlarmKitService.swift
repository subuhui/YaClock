import Foundation
import SwiftUI
import Combine

#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(AlarmKit)
struct EmptyMetadata: AlarmMetadata {}
#endif

/// A service to interact with iOS 26's AlarmKit framework, with fallback simulation for older iOS versions.
@MainActor
final class AlarmKitService: ObservableObject {
    static let shared = AlarmKitService()
    
    @Published var isAuthorized: Bool = false
    @Published var systemAlarms: [SystemAlarmInfo] = []
    
    // In-memory simulation queue for older iOS versions (like iOS 18.2 simulator)
    private var simulatedAlarms: [SystemAlarmInfo] = []
    
    struct SystemAlarmInfo: Identifiable, Hashable {
        let id: UUID
        let title: String
        let time: String
        let repeatString: String
        let isSimulated: Bool
    }
    
    private init() {
        checkAuthorization()
        
        // Start listening to system alarm updates if available
        if #available(iOS 26.0, *) {
            #if canImport(AlarmKit)
            Task {
                for await updatedAlarms in AlarmManager.shared.alarmUpdates {
                    self.updateSystemAlarms(from: updatedAlarms)
                }
            }
            #endif
        } else {
            // Simulated periodic check or initial load
            refreshSimulatedAlarms()
        }
    }
    
    func checkAuthorization() {
        if #available(iOS 26.0, *) {
            #if canImport(AlarmKit)
            let state = AlarmManager.shared.authorizationState
            self.isAuthorized = (state == .authorized)
            #else
            self.isAuthorized = true // Simulated fallback
            #endif
        } else {
            // Simulated fallback authorization state
            self.isAuthorized = UserDefaults.standard.bool(forKey: "AlarmKit_SimulatedAuthorized")
        }
    }
    
    func requestAuthorization() async -> Bool {
        if #available(iOS 26.0, *) {
            #if canImport(AlarmKit)
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                self.isAuthorized = (state == .authorized)
                return self.isAuthorized
            } catch {
                print("Failed to request AlarmKit authorization: \(error)")
                return false
            }
            #else
            self.isAuthorized = true
            return true
            #endif
        } else {
            // Simulated fallback
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            self.isAuthorized = true
            UserDefaults.standard.set(true, forKey: "AlarmKit_SimulatedAuthorized")
            refreshSimulatedAlarms()
            return true
        }
    }
    
    func scheduleAlarm(_ alarm: LocalAlarm) async throws {
        let repeatStr = formatRepeatDays(alarm.repeatDays)
        let timeStr = String(format: "%02d:%02d", alarm.hour, alarm.minute)
        
        if #available(iOS 26.0, *) {
            #if canImport(AlarmKit)
            // 1. Create alert presentation
            let alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: alarm.label),
                stopButton: AlarmButton(text: "停止", textColor: .white, systemImageName: "xmark.circle.fill")
            )
            
            // 2. Wrap in presentation attributes
            let attributes = AlarmAttributes<EmptyMetadata>(
                presentation: AlarmPresentation(alert: alertPresentation),
                tintColor: .blue
            )
            
            // 3. Set up relative schedule
            let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
            let weekdays = mapToWeekdays(alarm.repeatDays)
            let recurrence = weekdays.isEmpty ? Alarm.Schedule.Relative.Recurrence.never : Alarm.Schedule.Relative.Recurrence.weekly(weekdays)
            let schedule = Alarm.Schedule.relative(
                Alarm.Schedule.Relative(time: time, repeats: recurrence)
            )
            
            // 4. Construct configuration and schedule
            let configuration = AlarmManager.AlarmConfiguration<EmptyMetadata>(
                countdownDuration: nil,
                schedule: schedule,
                attributes: attributes
            )
            
            try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration)
            print("Successfully scheduled AlarmKit alarm with ID: \(alarm.id)")
            return
            #endif
        }
        
        // Fallback Simulation (iOS 18.2)
        print("[Simulator Mode] Scheduling simulated AlarmKit alarm: \(alarm.label) at \(timeStr), repeats: \(repeatStr)")
        simulatedAlarms.removeAll { $0.id == alarm.id }
        simulatedAlarms.append(
            SystemAlarmInfo(
                id: alarm.id,
                title: alarm.label,
                time: timeStr,
                repeatString: repeatStr,
                isSimulated: true
            )
        )
        refreshSimulatedAlarms()
    }
    
    func cancelAlarm(id: UUID) async throws {
        if #available(iOS 26.0, *) {
            #if canImport(AlarmKit)
            try AlarmManager.shared.cancel(id: id)
            print("Successfully cancelled AlarmKit alarm with ID: \(id)")
            return
            #endif
        }
        
        // Fallback Simulation (iOS 18.2)
        print("[Simulator Mode] Cancelling simulated AlarmKit alarm: \(id)")
        simulatedAlarms.removeAll { $0.id == id }
        refreshSimulatedAlarms()
    }
    
    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func updateSystemAlarms(from alarms: [AlarmKit.Alarm]) {
        self.systemAlarms = alarms.map { alarm in
            var timeStr = "--:--"
            var repeatStr = "只响一次"
            
            if let schedule = alarm.schedule {
                switch schedule {
                case .relative(let relativeSchedule):
                    timeStr = String(format: "%02d:%02d", relativeSchedule.time.hour, relativeSchedule.time.minute)
                    switch relativeSchedule.repeats {
                    case .never:
                        repeatStr = "只响一次"
                    case .weekly(let weekdays):
                        repeatStr = weekdays.map { $0.localizedName }.joined(separator: " ")
                    @unknown default:
                        repeatStr = "未知周期"
                    }
                case .fixed(let date):
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    timeStr = formatter.string(from: date)
                    repeatStr = "单次指定"
                @unknown default:
                    break
                }
            }
            
            var titleStr = "系统激活"
            switch alarm.state {
            case .alerting:
                titleStr = "响铃中"
            case .countdown:
                titleStr = "倒计时"
            case .paused:
                titleStr = "已暂停"
            case .scheduled:
                titleStr = "已调度"
            @unknown default:
                titleStr = "未知状态"
            }
            
            return SystemAlarmInfo(
                id: alarm.id,
                title: titleStr,
                time: timeStr,
                repeatString: repeatStr,
                isSimulated: false
            )
        }
    }
    #endif
    
    private func refreshSimulatedAlarms() {
        self.systemAlarms = simulatedAlarms.sorted(by: { $0.time < $1.time })
    }
    
    // MARK: - Helpers
    
    private func formatRepeatDays(_ days: [Int]) -> String {
        if days.isEmpty { return "只响一次" }
        if days.count == 7 { return "每天" }
        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return days.sorted().map { weekdayNames[$0 - 1] }.joined(separator: " ")
    }
    
    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func mapToWeekdays(_ days: [Int]) -> [Locale.Weekday] {
        return days.compactMap { day -> Locale.Weekday? in
            switch day {
            case 1: return .sunday
            case 2: return .monday
            case 3: return .tuesday
            case 4: return .wednesday
            case 5: return .thursday
            case 6: return .friday
            case 7: return .saturday
            default: return nil
            }
        }
    }
    #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
extension Locale.Weekday {
    var localizedName: String {
        switch self {
        case .sunday: return "周日"
        case .monday: return "周一"
        case .tuesday: return "周二"
        case .wednesday: return "周三"
        case .thursday: return "周四"
        case .friday: return "周五"
        case .saturday: return "周六"
        @unknown default: return ""
        }
    }
}
#endif
