// MARK: - Data Layer · AlarmKit Service
import Foundation
import SwiftUI
import Combine

#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(AlarmKit)
struct EmptyMetadata: AlarmMetadata {}
#endif

#if targetEnvironment(simulator)
private let isSimulator = true
#else
private let isSimulator = false
#endif

/// A service to interact with iOS 26's AlarmKit framework, with fallback simulation for older iOS versions.
@MainActor
final class AlarmKitService: AlarmServiceProtocol, ObservableObject {
    static let shared = AlarmKitService()
    
    @Published var isAuthorized: Bool = false
    @Published var systemAlarms: [SystemAlarmInfo] = []
    
    // In-memory simulation queue for older iOS versions (like iOS 18.2 simulator)
    private var simulatedAlarms: [SystemAlarmInfo] = []
    
    private init() {
        checkAuthorization()
        
        // Start listening to system alarm updates if available
        if #available(iOS 26.0, *), !isSimulator {
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
        if #available(iOS 26.0, *), !isSimulator {
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
        if #available(iOS 26.0, *), !isSimulator {
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
    
    func scheduleAlarm(_ entity: AlarmEntity) async throws {
        let repeatStr = formatRepeatDays(entity.repeatDays)
        let timeStr = String(format: "%02d:%02d", entity.hour, entity.minute)

        if #available(iOS 26.0, *), !isSimulator {
            #if canImport(AlarmKit)
            // 1. Create alert presentation
            let alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: entity.label),
                stopButton: AlarmButton(text: "停止", textColor: .white, systemImageName: "xmark.circle.fill")
            )

            // 2. Wrap in presentation attributes
            let attributes = AlarmAttributes<EmptyMetadata>(
                presentation: AlarmPresentation(alert: alertPresentation),
                tintColor: .blue
            )

            // 3. Set up relative schedule
            let time = Alarm.Schedule.Relative.Time(hour: entity.hour, minute: entity.minute)
            let weekdays = mapToWeekdays(entity.repeatDays)
            let recurrence = weekdays.isEmpty
                ? Alarm.Schedule.Relative.Recurrence.never
                : Alarm.Schedule.Relative.Recurrence.weekly(weekdays)
            let schedule = Alarm.Schedule.relative(
                Alarm.Schedule.Relative(time: time, repeats: recurrence)
            )

            // 4. Construct configuration
            let configuration = AlarmManager.AlarmConfiguration<EmptyMetadata>(
                countdownDuration: nil,
                schedule: schedule,
                attributes: attributes
            )

            // 5. cancel-then-schedule: schedule(id:) only creates new alarms;
            //    calling it on an existing ID causes Code=0.
            try? AlarmManager.shared.cancel(id: entity.id)
            try await AlarmManager.shared.schedule(id: entity.id, configuration: configuration)
            print("[AlarmKitService] Scheduled alarm \(entity.id)")
            return
            #endif
        }

        // Fallback: Simulator / iOS < 26
        print("[AlarmKitService] [Sim] Schedule \(entity.label) at \(timeStr) repeats:\(repeatStr) id:\(entity.id)")
        simulatedAlarms.removeAll { $0.id == entity.id }
        simulatedAlarms.append(
            SystemAlarmInfo(
                id: entity.id,
                title: entity.label,
                time: timeStr,
                repeatString: repeatStr,
                isSimulated: true
            )
        )
        refreshSimulatedAlarms()
    }
    
    func cancelAlarm(id: UUID) async throws {
        if #available(iOS 26.0, *), !isSimulator {
            #if canImport(AlarmKit)
            try AlarmManager.shared.cancel(id: id)
            print("Successfully cancelled AlarmKit alarm with ID: \(id)")
            return
            #endif
        }
        
        // Fallback Simulation (iOS 18.2)
        print("[AlarmKitService] [Simulator Mode] Cancelling simulated alarm: \(id)")
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
        print("[AlarmKitService] Real system alarms updated, count: \(self.systemAlarms.count)")
    }
    #endif
    
    private func refreshSimulatedAlarms() {
        self.systemAlarms = simulatedAlarms.sorted(by: { $0.time < $1.time })
        print("[AlarmKitService] Simulated system alarms refreshed, count: \(self.systemAlarms.count), current alarms: \(self.systemAlarms.map { "\($0.time) \($0.title)" })")
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
