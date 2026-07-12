// @Author subuhui
// @Date 2026/7/12 11:28
// @Description 日历 Tab 的 ViewModel，负责月份翻页、查询每日响铃实例和单日详情

import Foundation
import Observation

/// 日历页面的 ViewModel
@Observable
@MainActor
final class CalendarViewModel {

    // MARK: - 月份与选中日期状态

    /// 当前展示的月份
    var displayMonth: Date = Calendar.current.startOfMonth(for: Date())

    /// 用户当前选中的日期
    var selectedDate: Date = Date()

    /// 选中日期下的响铃实例（如果有）
    var selectedDayOccurrence: AlarmOccurrence?

    /// 选中日期的节假日状态
    var selectedDayHolidayType: HolidayType?

    /// 各天是否有响铃实例的快速索引（Key 为 yyyyMMdd 格式字符串）
    var ringingDays: Set<String> = []

    private let container: AppContainer
    private let ruleEngine = RuleEngine()
    private let holidays = HolidayProvider()

    init(container: AppContainer) {
        self.container = container
    }

    /// 视图出现时加载当月数据
    func onAppear() {
        loadMonthData()
        loadSelectedDayData()
    }

    /// 前翻一个月
    func previousMonth() {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth) else { return }
        displayMonth = prev
        loadMonthData()
    }

    /// 后翻一个月
    func nextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth) else { return }
        displayMonth = next
        loadMonthData()
    }

    /// 用户点击某天
    func selectDate(_ date: Date) {
        selectedDate = date
        loadSelectedDayData()
    }

    /// 跳过选中日期的响铃（创建 skip override）
    func skipSelectedDay() {
        guard let occ = selectedDayOccurrence else { return }
        let override = ScheduleOverride(
            scheduleID: occ.scheduleID,
            targetDate: selectedDate,
            action: .skip
        )
        Task {
            try await container.saveOverrideUseCase.execute(override)
            loadSelectedDayData()
        }
    }

    /// 修改选中日期的响铃时间
    func changeTime(to newTime: LocalTime) {
        guard let occ = selectedDayOccurrence else { return }
        let override = ScheduleOverride(
            scheduleID: occ.scheduleID,
            targetDate: selectedDate,
            action: .changeTime(newTime)
        )
        Task {
            try await container.saveOverrideUseCase.execute(override)
            loadSelectedDayData()
        }
    }

    /// 恢复选中日期的默认规则（删除 override）
    func restoreDefault() {
        guard let occ = selectedDayOccurrence else { return }
        Task {
            try await container.deleteOverrideUseCase.execute(
                scheduleID: occ.scheduleID,
                targetDate: selectedDate
            )
            loadSelectedDayData()
        }
    }

    // MARK: - 私有方法

    private func loadMonthData() {
        guard let monthRange = monthDateRange() else { return }
        var days = Set<String>()
        let schedules = (try? container.scheduleRepo.fetchAll()) ?? []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"

        for schedule in schedules where schedule.isEnabled {
            let overrides = (try? container.overrideRepo.fetchAll(for: schedule.id)) ?? []
            let occurrences = ruleEngine.generateOccurrences(
                for: schedule, overrides: overrides, holidays: holidays, in: monthRange
            )
            for occ in occurrences {
                days.insert(formatter.string(from: occ.fireDate))
            }
        }
        ringingDays = days
    }

    private func loadSelectedDayData() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let range = startOfDay...endOfDay

        let schedules = (try? container.scheduleRepo.fetchAll()) ?? []
        var earliest: AlarmOccurrence?

        for schedule in schedules where schedule.isEnabled {
            let overrides = (try? container.overrideRepo.fetchAll(for: schedule.id)) ?? []
            let occurrences = ruleEngine.generateOccurrences(
                for: schedule, overrides: overrides, holidays: holidays, in: range
            )
            if let first = occurrences.first {
                if earliest == nil || first.fireDate < earliest!.fireDate {
                    earliest = first
                }
            }
        }

        selectedDayOccurrence = earliest
        selectedDayHolidayType = holidays.checkHoliday(on: selectedDate)
    }

    private func monthDateRange() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)),
              let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return nil }
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return start...endOfDay
    }
}

extension Calendar {
    /// 返回给定日期所在月份的第一天
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
