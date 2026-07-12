// @Author subuhui
// @Date 2026/7/12 10:49
// @Description 对账引擎 UseCase：计算未来 60 天的预期响铃实例，与系统队列做 Diff 并同步

import Foundation

/// 对账引擎：计算全量作息的预期响铃实例集合，与 AlarmKit 系统队列做 Diff，执行增删调度
/// 这是保障 App 离线运行、防漏响的核心机制
final class RefreshScheduledAlarmsUseCase {

    /// 未来预计算的天数范围，可根据 AlarmKit 队列上限调整
    private let lookaheadDays = 60

    private let scheduleRepo: ScheduleRepository
    private let overrideRepo: OverrideRepository
    private let occurrenceRepo: ScheduledOccurrenceRepository
    private let scheduler: AlarmScheduler
    private let ruleEngine = RuleEngine()
    private let holidays = HolidayProvider()

    /// 初始化对账引擎
    /// - Parameters:
    ///   - scheduleRepo: 作息表仓储
    ///   - overrideRepo: 单日覆盖仓储
    ///   - occurrenceRepo: 已调度实例仓储
    ///   - scheduler: 调度器（真机或模拟器实现）
    init(
        scheduleRepo: ScheduleRepository,
        overrideRepo: OverrideRepository,
        occurrenceRepo: ScheduledOccurrenceRepository,
        scheduler: AlarmScheduler
    ) {
        self.scheduleRepo = scheduleRepo
        self.overrideRepo = overrideRepo
        self.occurrenceRepo = occurrenceRepo
        self.scheduler = scheduler
    }

    /// 执行全量对账：计算预期 → 与系统对比 → 增删调度
    func execute() async throws {
        let now = Date()
        guard let future = Calendar.current.date(byAdding: .day, value: lookaheadDays, to: now) else { return }
        let dateRange = now...future

        // 1. 计算所有启用作息的预期响铃实例集合
        let schedules = try scheduleRepo.fetchAll()
        var expectedOccurrences = [UUID: AlarmOccurrence]()

        for schedule in schedules where schedule.isEnabled {
            let overrides = try overrideRepo.fetchAll(for: schedule.id)
            let occurrences = ruleEngine.generateOccurrences(
                for: schedule,
                overrides: overrides,
                holidays: holidays,
                in: dateRange
            )
            for occurrence in occurrences {
                expectedOccurrences[occurrence.id] = occurrence
            }
        }

        // 2. 读取系统当前已调度的 ID 集合
        let systemScheduledIDs = try await scheduler.scheduledIDs()

        // 3. 计算三个差集
        let expectedIDs = Set(expectedOccurrences.keys)

        // 需要新增下发的：在预期中，但系统队列没有
        let toSchedule = expectedIDs.subtracting(systemScheduledIDs)

        // 需要取消的：系统队列中有，但预期中不再需要
        let toCancel = systemScheduledIDs.subtracting(expectedIDs)

        // 4. 执行取消
        for id in toCancel {
            try await scheduler.cancel(id: id)
            try occurrenceRepo.markCancelled(id: id)
        }

        // 5. 执行新增调度
        for id in toSchedule {
            guard let occurrence = expectedOccurrences[id] else { continue }
            try await scheduler.schedule(occurrence)
            try occurrenceRepo.markScheduled(occurrence: occurrence)
        }
    }
}
