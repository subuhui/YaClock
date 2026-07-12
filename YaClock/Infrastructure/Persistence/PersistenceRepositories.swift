// @Author subuhui
// @Date 2026/7/12 10:49
// @Description SwiftData 仓储实现，提供作息表与单日覆盖的 CRUD 操作

import Foundation
import SwiftData

// MARK: - ScheduleRepository

/// 作息表的持久化仓储，以 ModelContext 为底层存储，负责 Schedule 的增删改查
final class ScheduleRepository {

    /// SwiftData 数据上下文，调用方负责保证在正确的线程（主线程）访问
    private let context: ModelContext

    /// 初始化作息仓储
    /// - Parameter context: SwiftData 的 ModelContext 实例
    init(context: ModelContext) {
        self.context = context
    }

    /// 获取所有作息表
    /// - Returns: 所有持久化的 Schedule 实体数组
    func fetchAll() throws -> [Schedule] {
        let descriptor = FetchDescriptor<LocalSchedule>()
        let locals = try context.fetch(descriptor)
        return try locals.map { try $0.toDomain() }
    }

    /// 保存（新建或更新）一个作息表
    /// 如果相同 ID 的记录已存在，则更新其字段；否则插入新记录
    /// - Parameter schedule: 需要保存的 Domain 作息实体
    func save(_ schedule: Schedule) throws {
        let id = schedule.id
        let descriptor = FetchDescriptor<LocalSchedule>(
            predicate: #Predicate { $0.id == id }
        )
        let existing = try context.fetch(descriptor).first

        let ruleData = try JSONEncoder().encode(schedule.rule)

        if let local = existing {
            // 更新已有记录
            local.name = schedule.name
            local.timeHour = schedule.time.hour
            local.timeMinute = schedule.time.minute
            local.ruleData = ruleData
            local.soundName = schedule.sound.name
            local.soundTypeRaw = schedule.sound.type.rawValue
            local.snoozeEnabled = schedule.snooze.isEnabled
            local.snoozeDurationMinutes = schedule.snooze.durationMinutes
            local.isEnabled = schedule.isEnabled
            local.startDate = schedule.startDate
            local.endDate = schedule.endDate
        } else {
            // 插入新记录
            let local = try LocalSchedule.from(schedule)
            context.insert(local)
        }

        try context.save()
    }

    /// 删除指定 ID 的作息表
    /// - Parameter id: 要删除的作息表 ID
    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<LocalSchedule>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = try context.fetch(descriptor).first {
            context.delete(local)
            try context.save()
        }
    }
}

// MARK: - OverrideRepository

/// 单日临时覆盖的持久化仓储
final class OverrideRepository {

    private let context: ModelContext

    /// 初始化覆盖规则仓储
    /// - Parameter context: SwiftData 的 ModelContext 实例
    init(context: ModelContext) {
        self.context = context
    }

    /// 获取指定作息表的所有单日覆盖
    /// - Parameter scheduleID: 关联的作息表 ID
    /// - Returns: 该作息表下所有的 ScheduleOverride 数组
    func fetchAll(for scheduleID: UUID) throws -> [ScheduleOverride] {
        let descriptor = FetchDescriptor<LocalScheduleOverride>(
            predicate: #Predicate { $0.scheduleID == scheduleID }
        )
        let locals = try context.fetch(descriptor)
        return try locals.map { try $0.toDomain() }
    }

    /// 保存（新建或更新）一个单日覆盖规则
    func save(_ override: ScheduleOverride) throws {
        let id = override.id
        let descriptor = FetchDescriptor<LocalScheduleOverride>(
            predicate: #Predicate { $0.id == id }
        )
        let existing = try context.fetch(descriptor).first
        let actionData = try JSONEncoder().encode(override.action)

        if let local = existing {
            local.actionData = actionData
        } else {
            let local = LocalScheduleOverride(
                id: override.id,
                scheduleID: override.scheduleID,
                targetDate: override.targetDate,
                actionData: actionData
            )
            context.insert(local)
        }

        try context.save()
    }

    /// 删除指定 ID 的单日覆盖规则
    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<LocalScheduleOverride>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = try context.fetch(descriptor).first {
            context.delete(local)
            try context.save()
        }
    }

    /// 删除指定作息表下指定日期的覆盖（恢复默认），用于"恢复默认"操作
    func delete(scheduleID: UUID, targetDate: Date) throws {
        let descriptor = FetchDescriptor<LocalScheduleOverride>(
            predicate: #Predicate { $0.scheduleID == scheduleID && $0.targetDate == targetDate }
        )
        for local in try context.fetch(descriptor) {
            context.delete(local)
        }
        try context.save()
    }
}

// MARK: - ScheduledOccurrenceRepository

/// 已调度闹铃实例映射的持久化仓储，用于对账引擎追踪已下发系统的闹铃状态
final class ScheduledOccurrenceRepository {

    private let context: ModelContext

    /// 初始化已调度实例仓储
    init(context: ModelContext) {
        self.context = context
    }

    /// 获取所有已记录的已调度闹铃实例
    func fetchAll() throws -> [LocalScheduledOccurrence] {
        let descriptor = FetchDescriptor<LocalScheduledOccurrence>()
        return try context.fetch(descriptor)
    }

    /// 记录一个已成功调度的闹铃实例
    func markScheduled(occurrence: AlarmOccurrence) throws {
        let id = occurrence.id
        let descriptor = FetchDescriptor<LocalScheduledOccurrence>(
            predicate: #Predicate { $0.id == id }
        )
        if try context.fetch(descriptor).isEmpty {
            let local = LocalScheduledOccurrence(
                id: occurrence.id,
                scheduleID: occurrence.scheduleID,
                fireDate: occurrence.fireDate
            )
            context.insert(local)
            try context.save()
        }
    }

    /// 删除已取消调度的闹铃实例记录
    func markCancelled(id: UUID) throws {
        let descriptor = FetchDescriptor<LocalScheduledOccurrence>(
            predicate: #Predicate { $0.id == id }
        )
        if let local = try context.fetch(descriptor).first {
            context.delete(local)
            try context.save()
        }
    }

    /// 删除指定作息表下的所有已调度记录，通常在删除作息时调用
    func deleteAll(for scheduleID: UUID) throws {
        let descriptor = FetchDescriptor<LocalScheduledOccurrence>(
            predicate: #Predicate { $0.scheduleID == scheduleID }
        )
        for local in try context.fetch(descriptor) {
            context.delete(local)
        }
        try context.save()
    }
}
