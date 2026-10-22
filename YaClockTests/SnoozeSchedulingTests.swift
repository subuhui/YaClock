// @Author zhangzheming
// @Date 2026/10/22 22:32
// @Description 验证保存贪睡设置会更新已有系统闹钟，且不会重复下发其他作息

import Foundation
import SwiftData
import Testing
@testable import YaClock

@MainActor
struct SnoozeSchedulingTests {
    /// 覆盖修改分钟数、开启和关闭贪睡三种不改变闹钟 ID 的保存操作
    @Test(arguments: [
        (SnoozeConfiguration.disabled, SnoozeConfiguration(isEnabled: true, durationMinutes: 3)),
        (SnoozeConfiguration(isEnabled: true, durationMinutes: 9), SnoozeConfiguration(isEnabled: true, durationMinutes: 12)),
        (SnoozeConfiguration(isEnabled: true, durationMinutes: 9), SnoozeConfiguration.disabled)
    ])
    func savingSnoozeUpdatesExistingAlarm(initial: SnoozeConfiguration, snooze: SnoozeConfiguration) async throws {
        let schema = Schema([LocalSchedule.self, LocalScheduleOverride.self, LocalScheduledOccurrence.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let scheduler = RecordingScheduler()
        let app = AppContainer(context: container.mainContext, scheduler: scheduler)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var schedule = Schedule(
            name: "贪睡测试",
            time: LocalTime(hour: 8, minute: 0),
            rule: .once(OnceRule(date: tomorrow)),
            snooze: initial
        )
        let other = Schedule(
            name: "其他闹钟",
            time: LocalTime(hour: 9, minute: 0),
            rule: .once(OnceRule(date: tomorrow))
        )
        try await app.saveScheduleUseCase.execute(schedule)
        try await app.saveScheduleUseCase.execute(other)
        let original = try #require(scheduler.alarms.values.first { $0.scheduleID == schedule.id })
        let callsBeforeSaving = scheduler.scheduledCalls.count

        schedule.snooze = snooze
        try await app.saveScheduleUseCase.execute(schedule)

        let updated = try #require(scheduler.alarms[original.id])
        #expect(updated.snooze == snooze)
        #expect(scheduler.alarms.count == 2)
        #expect(scheduler.scheduledCalls.count == callsBeforeSaving + 1)
        #expect(scheduler.scheduledCalls.last?.id == original.id)
        #expect(try app.scheduleRepo.fetchAll().first { $0.id == schedule.id }?.snooze == snooze)

        // 普通前台对账不应重复下发未修改的闹钟
        try await app.refreshUseCase.execute()
        #expect(scheduler.scheduledCalls.count == callsBeforeSaving + 1)
    }
}

/// 记录实际收到的实例，检验相同 ID 下的配置是否重新下发
@MainActor
private final class RecordingScheduler: AlarmScheduler {
    /// 当前模拟系统队列
    var alarms: [UUID: AlarmOccurrence] = [:]
    /// 每次下发的历史记录，用于检查更新范围
    var scheduledCalls: [AlarmOccurrence] = []

    /// 模拟真机调度器的同 ID 替换行为
    func schedule(_ occurrence: AlarmOccurrence) async throws {
        alarms[occurrence.id] = occurrence
        scheduledCalls.append(occurrence)
    }

    /// 模拟取消已下发的闹钟
    func cancel(id: UUID) async throws {
        alarms.removeValue(forKey: id)
    }

    /// 返回当前模拟系统队列的 ID
    func scheduledIDs() async throws -> Set<UUID> {
        Set(alarms.keys)
    }
}
