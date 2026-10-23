// @Author subuhui
// @Date 2026/7/12 10:49
// @Description 对账引擎 UseCase：计算未来 60 天的预期响铃实例，与系统队列做 Diff 并同步

import Foundation
import Observation
import WidgetKit

/// 对账引擎：计算全量作息的预期响铃实例集合，与 AlarmKit 系统队列做 Diff，执行增删调度
/// 这是保障 App 离线运行、防漏响的核心机制
@Observable
final class RefreshScheduledAlarmsUseCase {
    private(set) var isRefreshing = false
    private(set) var lastSync: Date?
    private(set) var errorMessage: String?
    private(set) var scheduledThrough: Date?
    private(set) var confirmedIDs: Set<UUID> = []
    private(set) var expected: [AlarmOccurrence] = []
    private(set) var missingHolidayYears: [Int] = []
    private var pending: Task<Void, Error>?
    private var horizonEnd: Date?

    var permission: AlarmPermission { scheduler.permission }
    var missingCount: Int { expected.filter { !confirmedIDs.contains($0.id) }.count }

    func requestPermission() async throws {
        let result = try await scheduler.requestPermission()
        guard result == .authorized || result == .simulated else { throw AlarmPermissionError.denied }
        try await execute()
    }

    func execute(rescheduling scheduleID: UUID? = nil) async throws {
        let previous = pending
        let task = Task {
            // 排队执行，避免保存和前台刷新在 await 处交错修改系统队列。
            if let previous { _ = await previous.result }
            isRefreshing = true
            errorMessage = nil
            scheduledThrough = nil
            defer { isRefreshing = false }
            do {
                try await reconcile(rescheduling: scheduleID)
                lastSync = Date()
                try publishWidget()
            } catch {
                errorMessage = error.localizedDescription
                try publishWidget()
                throw error
            }
        }
        pending = task
        try await task.value
    }

    func verifyQueue() async {
        guard !isRefreshing else { return }
        do {
            let systemIDs = try await scheduler.scheduledIDs()
            guard !isRefreshing else { return }
            confirmedIDs = systemIDs
            expected.removeAll { $0.fireDate <= Date() }
            if missingCount > 0 {
                errorMessage = "系统队列发生变化，部分闹钟缺失，请重新同步。"
                scheduledThrough = nil
            }
            try publishWidget()
        } catch { errorMessage = error.localizedDescription }
    }

    private func publishWidget() throws {
        let now = Date()
        let calendar = Calendar.current
        let schedules = try scheduleRepo.fetchAll().filter(\.isEnabled)
        let summaries: [AlarmWidgetSnapshot.DaySummary] = (0...lookaheadDays).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
            let dayMark: String
            switch holidays.checkHoliday(on: date) {
            case .holiday(let name): dayMark = name + "假期"
            case .workday(let reason): dayMark = reason
            case nil: dayMark = calendar.isDateInWeekend(date) ? "周末" : "工作日"
            }
            let labels = schedules.compactMap { schedule -> String? in
                guard date >= calendar.startOfDay(for: schedule.startDate),
                      schedule.endDate.map({ date <= calendar.startOfDay(for: $0) }) ?? true else { return nil }
                if let start = schedule.vacationStart, let end = schedule.vacationEnd,
                   date >= calendar.startOfDay(for: start), date <= calendar.startOfDay(for: end) {
                    return schedule.name + "休假"
                }
                if case .cycle(let rule) = schedule.rule, !rule.cycleDays.isEmpty {
                    let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: rule.anchorDate), to: date).day!
                    let index = ((diff % rule.cycleDays.count) + rule.cycleDays.count) % rule.cycleDays.count
                    return schedule.name + " · " + rule.cycleDays[index].name
                }
                return expected.contains(where: { $0.scheduleID == schedule.id && calendar.isDate($0.fireDate, inSameDayAs: date) }) ? schedule.name : nil
            }
            return .init(date: date, text: dayMark + " · " + (labels.isEmpty ? "无闹钟" : labels.joined(separator: "、")))
        }
        let status: String
        if errorMessage != nil { status = "调度异常，请打开应用修复" }
        else {
            switch permission {
            case .simulated: status = "模拟模式，不会实际响铃"
            case .authorized: status = "已核对系统队列"
            case .denied, .notDetermined: status = "闹钟权限未开启，请打开应用"
            }
        }
        try AlarmWidgetSnapshot(daySummaries: summaries, generatedAt: now,
            validUntil: horizonEnd ?? now,
            alarms: expected.map { .init(date: $0.fireDate, label: $0.label, confirmed: confirmedIDs.contains($0.id)) },
            status: status).write()
        WidgetCenter.shared.reloadAllTimelines()
    }

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
    /// - Parameter scheduleID: 保存后需要重新下发配置的作息，避免稳定 ID 导致贪睡等设置被跳过
    private func reconcile(rescheduling scheduleID: UUID?) async throws {
        let now = Date()
        guard let future = Calendar.current.date(byAdding: .day, value: lookaheadDays, to: now) else { return }
        horizonEnd = future

        // 1. 计算所有启用作息的预期响铃实例集合
        let schedules = try scheduleRepo.fetchAll()
        var expectedOccurrences = [UUID: AlarmOccurrence]()

        for schedule in schedules where schedule.isEnabled {
            let overrides = try overrideRepo.fetchAll(for: schedule.id)
            let occurrences = ruleEngine.upcomingOccurrences(
                for: schedule,
                overrides: overrides,
                holidays: holidays,
                from: now, horizonDays: lookaheadDays
            )
            for occurrence in occurrences {
                expectedOccurrences[occurrence.id] = occurrence
            }
        }

        expected = expectedOccurrences.values.sorted { $0.fireDate < $1.fireDate }
        let globalPolicy = ChineseWorkdayPolicy(rawValue: UserDefaults.standard.string(forKey: "defaultHolidayPolicy") ?? "") ?? .skipHoliday
        let needsHolidays = schedules.contains { schedule in
            guard schedule.isEnabled else { return false }
            switch schedule.rule {
            case .once: return false
            case .chineseWorkday(let rule): return rule.policy != .ignoreHoliday
            default: return globalPolicy != .ignoreHoliday
            }
        }
        let lastPlanned = max(future, expected.last?.fireDate ?? future)
        missingHolidayYears = needsHolidays ? HolidayProvider.missingYears(in: now...lastPlanned) : []

        // 2. 读取系统当前已调度的 ID 集合
        let systemScheduledIDs = try await scheduler.scheduledIDs()
        confirmedIDs = systemScheduledIDs

        // 3. 计算三个差集
        let expectedIDs = Set(expectedOccurrences.keys)

        // 需要新增下发的：在预期中，但系统队列没有
        let toUpdate = Set(expectedOccurrences.values.filter { $0.scheduleID == scheduleID }.map { $0.id })
        let toSchedule = expectedIDs.subtracting(systemScheduledIDs).union(toUpdate)

        // 需要取消的：系统队列中有，但预期中不再需要
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let protectedScheduleIDs = Set(schedules.filter { schedule in
            guard schedule.isEnabled else { return false }
            if let start = schedule.vacationStart, let end = schedule.vacationEnd,
               today >= calendar.startOfDay(for: start), today <= calendar.startOfDay(for: end) {
                return false
            }
            return true
        }.map(\.id))
        let activeIDs = try await scheduler.activeIDs()
        let protectedIDs = Set(try occurrenceRepo.fetchAll().filter {
            activeIDs.contains($0.id) && protectedScheduleIDs.contains($0.scheduleID) && $0.fireDate < now
        }.map(\.id))
        let toCancel = systemScheduledIDs.subtracting(expectedIDs).subtracting(protectedIDs)

        // 4. 执行取消
        for id in toCancel {
            try await scheduler.cancel(id: id)
            confirmedIDs.remove(id)
            try occurrenceRepo.markCancelled(id: id)
        }

        // 5. 执行新增调度
        for occurrence in expected where toSchedule.contains(occurrence.id) {
            let id = occurrence.id
            confirmedIDs.remove(id)
            try await scheduler.schedule(occurrence)
            confirmedIDs.insert(id)
            try occurrenceRepo.markScheduled(occurrence: occurrence)
        }
        confirmedIDs = try await scheduler.scheduledIDs()
        // 修复本地映射丢失及过期记录，仅以系统队列作为成功证据。
        for occurrence in expected where confirmedIDs.contains(occurrence.id) {
            try occurrenceRepo.markScheduled(occurrence: occurrence)
        }
        for local in try occurrenceRepo.fetchAll() where !confirmedIDs.contains(local.id) {
            try occurrenceRepo.markCancelled(id: local.id)
        }
        guard missingCount == 0 else { throw SchedulingVerificationError.incomplete }
        scheduledThrough = future
    }
}

private enum SchedulingVerificationError: LocalizedError {
    case incomplete
    var errorDescription: String? { "部分闹钟未在系统队列中找到，请重新同步。" }
}

private enum AlarmPermissionError: LocalizedError {
    case denied
    var errorDescription: String? { "闹钟权限未开启，请在系统设置中允许 YaClock 使用闹钟。" }
}
