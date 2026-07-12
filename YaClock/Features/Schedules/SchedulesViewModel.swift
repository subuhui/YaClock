// @Author subuhui
// @Date 2026/7/12 11:57
// @Description 作息 Tab 页面的 ViewModel，管理作息列表加载、即将响铃实例查询和删除操作

import Foundation
import Observation

/// 作息列表页面的 ViewModel
@Observable
@MainActor
final class SchedulesViewModel {

    // MARK: - 状态属性

    /// 全部作息表列表
    var schedules: [Schedule] = []

    /// 未来 60 天内最近的一次响铃实例（用于顶部 Banner）
    var nextOccurrence: AlarmOccurrence?

    private let container: AppContainer
    private let ruleEngine = RuleEngine()
    private let holidays = HolidayProvider()

    init(container: AppContainer) {
        self.container = container
    }

    /// 视图出现时加载数据
    func onAppear() {
        load()
    }

    /// 删除指定作息表
    func delete(id: UUID) {
        Task {
            try await container.deleteScheduleUseCase.execute(id: id)
            load()
        }
    }

    // MARK: - 私有方法

    private func load() {
        schedules = (try? container.scheduleRepo.fetchAll()) ?? []
        computeNextOccurrence()
    }

    private func computeNextOccurrence() {
        let now = Date()
        guard let future = Calendar.current.date(byAdding: .day, value: 60, to: now) else { return }

        var earliest: AlarmOccurrence?
        for schedule in schedules where schedule.isEnabled {
            let overrides = (try? container.overrideRepo.fetchAll(for: schedule.id)) ?? []
            let occurrences = ruleEngine.generateOccurrences(
                for: schedule,
                overrides: overrides,
                holidays: holidays,
                in: now...future
            )
            for occ in occurrences where occ.fireDate > now {
                if earliest == nil || occ.fireDate < earliest!.fireDate {
                    earliest = occ
                }
            }
        }
        nextOccurrence = earliest
    }

    /// 计算指定作息表的倒计时描述（如"将在 8 小时 12 分钟后响起"）
    func countdownDescription(for schedule: Schedule) -> String? {
        let now = Date()
        guard let future = Calendar.current.date(byAdding: .day, value: 60, to: now) else { return nil }
        let overrides = (try? container.overrideRepo.fetchAll(for: schedule.id)) ?? []
        let occurrences = ruleEngine.generateOccurrences(
            for: schedule, overrides: overrides, holidays: holidays, in: now...future
        )
        guard let next = occurrences.first(where: { $0.fireDate > now }) else { return nil }
        let diff = next.fireDate.timeIntervalSince(now)
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        return "将在 \(h) 小时 \(m) 分钟后响起"
    }
}
