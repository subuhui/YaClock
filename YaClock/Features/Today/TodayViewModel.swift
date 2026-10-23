// @Author subuhui
// @Date 2026/7/12 11:28
// @Description Today 页面的 ViewModel，负责查询下一次响铃实例、今日作息状态和常用计划列表

import Foundation
import Observation

/// Today 页面的 ViewModel
@Observable
@MainActor
final class TodayViewModel {

    // MARK: - 状态属性

    /// 下一次即将响铃的实例，包含长假结束后的补排窗口
    var nextOccurrence: AlarmOccurrence?

    /// 下一次响铃距今的时间描述（如"明天 · 剩余 8 小时 15 分钟"）
    var countdownText: String = ""

    /// 今日日程状态描述（如"今天是工作日（调休）"）
    var todayStatusText: String = ""

    /// 全部作息列表（用于首页"常用计划"展示，最多显示前 3 条）
    var schedules: [Schedule] = []

    /// 当前是否有 AlarmKit 权限
    var hasPermission: Bool = true
    var errorMessage: String?
    var isAdjusting = false

    private let container: AppContainer
    private let ruleEngine = RuleEngine()
    private let holidays = HolidayProvider()

    /// 定时器，用于每分钟刷新倒计时显示
    private var timer: Timer?

    init(container: AppContainer) {
        self.container = container
    }

    /// 页面出现时加载数据
    func onAppear() {
        load()
        startTimer()
    }

    /// 页面消失时停止定时器
    func onDisappear() {
        timer?.invalidate()
        timer = nil
    }

    /// 切换指定作息的启用状态
    func toggle(id: UUID) {
        Task {
            do { try await container.toggleScheduleUseCase.execute(id: id) }
            catch { errorMessage = error.localizedDescription }
            load()
        }
    }

    func adjust(_ occurrence: AlarmOccurrence, action: ScheduleOverride.Action) {
        isAdjusting = true
        Task {
            do {
                try await container.saveOverrideUseCase.execute(.init(
                    scheduleID: occurrence.scheduleID, targetDate: occurrence.fireDate, action: action))
            } catch { errorMessage = "临时调整未完全同步：\(error.localizedDescription)" }
            load()
            isAdjusting = false
        }
    }

    func refresh() { load() }

    // MARK: - 私有方法

    private func load() {
        hasPermission = container.scheduler.permission != .denied
        do {
            schedules = try container.scheduleRepo.fetchAll()
            try computeNextOccurrence()
            computeTodayStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func computeNextOccurrence() throws {
        let now = Date()

        var earliest: AlarmOccurrence?
        for schedule in schedules where schedule.isEnabled {
            let overrides = try container.overrideRepo.fetchAll(for: schedule.id)
            let occurrences = ruleEngine.upcomingOccurrences(
                for: schedule,
                overrides: overrides,
                holidays: holidays,
                from: now
            )
            for occ in occurrences {
                if occ.fireDate > now {
                    if earliest == nil || occ.fireDate < earliest!.fireDate {
                        earliest = occ
                    }
                }
            }
        }

        nextOccurrence = earliest
        updateCountdownText()
    }

    private func updateCountdownText() {
        guard let next = nextOccurrence else {
            countdownText = "暂无计划"
            return
        }
        let now = Date()
        let diff = next.fireDate.timeIntervalSince(now)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60

        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(next.fireDate)
        let isTomorrow = calendar.isDateInTomorrow(next.fireDate)

        let dayLabel = isToday ? "今天" : isTomorrow ? "明天" : ""
        countdownText = "\(dayLabel) · 剩余 \(hours) 小时 \(minutes) 分钟"
    }

    private func computeTodayStatus() {
        let today = Date()
        if let holiday = holidays.checkHoliday(on: today) {
            switch holiday {
            case .holiday(let name):
                todayStatusText = "今天是\(name)假期"
            case .workday(let reason):
                todayStatusText = "今天是工作日（\(reason)）"
            }
        } else {
            let weekday = Calendar.current.component(.weekday, from: today)
            // 周六=7，周日=1
            if weekday == 1 || weekday == 7 {
                todayStatusText = "今天是周末"
            } else {
                todayStatusText = "今天是工作日"
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.load()
            }
        }
    }
}
