import Foundation

/// 模板仅填充编辑器；用户保存前不会创建或下发闹钟。
enum ScheduleTemplate: String, CaseIterable, Identifiable {
    case weekdays = "双休", alternating = "大小周", twoOnTwoOff = "上二休二", shifts = "白白夜夜休休"
    var id: String { rawValue }

    func makeSchedule(now: Date = Date()) -> Schedule {
        let rule: ScheduleRule
        switch self {
        case .weekdays:
            rule = .chineseWorkday(.init(policy: .followHoliday, repeatDays: [2, 3, 4, 5, 6]))
        case .alternating:
            rule = .alternatingWeeks(.init(anchorDate: now, anchorWeekType: .weekA,
                weekAWorkdays: [2, 3, 4, 5, 6, 7], weekBWorkdays: [2, 3, 4, 5, 6]))
        case .twoOnTwoOff:
            rule = .cycle(.init(anchorDate: now, cycleDays: [
                .init(name: "上班", isWorking: true, isRinging: true),
                .init(name: "上班", isWorking: true, isRinging: true),
                .init(name: "休息", isWorking: false, isRinging: false),
                .init(name: "休息", isWorking: false, isRinging: false)]))
        case .shifts:
            rule = .cycle(.init(anchorDate: now, cycleDays: [
                .init(name: "白班", isWorking: true, isRinging: true),
                .init(name: "白班", isWorking: true, isRinging: true),
                .init(name: "夜班", isWorking: true, isRinging: true, timeOverride: .init(hour: 18, minute: 0)),
                .init(name: "夜班", isWorking: true, isRinging: true, timeOverride: .init(hour: 18, minute: 0)),
                .init(name: "休息", isWorking: false, isRinging: false),
                .init(name: "休息", isWorking: false, isRinging: false)]))
        }
        return Schedule(name: rawValue, time: .init(hour: 7, minute: 30), rule: rule, startDate: now)
    }
}

extension Schedule {
    func copyForCreation() -> Schedule {
        Schedule(name: name + " 副本", time: time, rule: rule, sound: sound, snooze: snooze,
                 isEnabled: isEnabled, startDate: Date(), endDate: endDate)
    }
}
