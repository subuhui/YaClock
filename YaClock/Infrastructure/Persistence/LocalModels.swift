// @Author subuhui
// @Date 2026/7/12 10:49
// @Description SwiftData 本地持久化模型定义，包含作息表、临时覆盖与已调度实例的映射

import Foundation
import SwiftData

// MARK: - LocalSchedule

/// 作息表的 SwiftData 持久化模型
/// 将 Domain 层的 Schedule 值类型转换后存储，rule 以 JSON 二进制数据保存以支持多态
@Model
final class LocalSchedule {
    /// 稳定唯一标识符，与 Domain 层 Schedule.id 对齐
    @Attribute(.unique) var id: UUID

    /// 作息名称
    var name: String

    /// 响铃时间的小时部分
    var timeHour: Int

    /// 响铃时间的分钟部分
    var timeMinute: Int

    /// ScheduleRule 的 JSON 序列化数据，支持多种规则类型的多态存储
    var ruleData: Data

    /// 铃声名称
    var soundName: String

    /// 铃声类型原始值（"system" 或 "custom"）
    var soundTypeRaw: String

    /// 是否开启贪睡
    var snoozeEnabled: Bool

    /// 贪睡延迟分钟数
    var snoozeDurationMinutes: Int

    /// 是否启用
    var isEnabled: Bool

    /// 作息生效起始日期
    var startDate: Date

    /// 作息结束日期，nil 表示永久有效
    var endDate: Date?

    init(
        id: UUID,
        name: String,
        timeHour: Int,
        timeMinute: Int,
        ruleData: Data,
        soundName: String,
        soundTypeRaw: String,
        snoozeEnabled: Bool,
        snoozeDurationMinutes: Int,
        isEnabled: Bool,
        startDate: Date,
        endDate: Date?
    ) {
        self.id = id
        self.name = name
        self.timeHour = timeHour
        self.timeMinute = timeMinute
        self.ruleData = ruleData
        self.soundName = soundName
        self.soundTypeRaw = soundTypeRaw
        self.snoozeEnabled = snoozeEnabled
        self.snoozeDurationMinutes = snoozeDurationMinutes
        self.isEnabled = isEnabled
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - LocalScheduleOverride

/// 单日临时覆盖规则的 SwiftData 持久化模型
@Model
final class LocalScheduleOverride {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID

    /// 关联的作息表 ID
    var scheduleID: UUID

    /// 覆盖生效的目标日期（已标准化为当天 00:00:00）
    var targetDate: Date

    /// ScheduleOverride.Action 的 JSON 序列化数据
    var actionData: Data

    init(id: UUID, scheduleID: UUID, targetDate: Date, actionData: Data) {
        self.id = id
        self.scheduleID = scheduleID
        self.targetDate = targetDate
        self.actionData = actionData
    }
}

// MARK: - LocalScheduledOccurrence

/// 已成功下发到 AlarmKit 的闹铃实例映射，用于对账时追踪系统队列状态
@Model
final class LocalScheduledOccurrence {
    /// 与 AlarmOccurrence.id 对齐的稳定 ID，也用于 AlarmKit 的 alarm ID
    @Attribute(.unique) var id: UUID

    /// 关联的源作息表 ID
    var scheduleID: UUID

    /// 实际下发给 AlarmKit 的响铃时间
    var fireDate: Date

    init(id: UUID, scheduleID: UUID, fireDate: Date) {
        self.id = id
        self.scheduleID = scheduleID
        self.fireDate = fireDate
    }
}

// MARK: - Domain <-> LocalSchedule 互转

extension LocalSchedule {
    /// 将 Domain 层的 Schedule 值类型转换为 SwiftData 持久化对象
    /// - Parameter schedule: Domain 层作息表实体
    /// - Returns: 可持久化的 LocalSchedule 对象
    static func from(_ schedule: Schedule) throws -> LocalSchedule {
        let ruleData = try JSONEncoder().encode(schedule.rule)
        return LocalSchedule(
            id: schedule.id,
            name: schedule.name,
            timeHour: schedule.time.hour,
            timeMinute: schedule.time.minute,
            ruleData: ruleData,
            soundName: schedule.sound.name,
            soundTypeRaw: schedule.sound.type.rawValue,
            snoozeEnabled: schedule.snooze.isEnabled,
            snoozeDurationMinutes: schedule.snooze.durationMinutes,
            isEnabled: schedule.isEnabled,
            startDate: schedule.startDate,
            endDate: schedule.endDate
        )
    }

    /// 将 SwiftData 持久化对象还原为 Domain 层的 Schedule 值类型
    func toDomain() throws -> Schedule {
        let rule = try JSONDecoder().decode(ScheduleRule.self, from: ruleData)
        let soundType = AlarmSound.SoundType(rawValue: soundTypeRaw) ?? .system
        return Schedule(
            id: id,
            name: name,
            time: LocalTime(hour: timeHour, minute: timeMinute),
            rule: rule,
            sound: AlarmSound(name: soundName, type: soundType),
            snooze: SnoozeConfiguration(isEnabled: snoozeEnabled, durationMinutes: snoozeDurationMinutes),
            isEnabled: isEnabled,
            startDate: startDate,
            endDate: endDate
        )
    }
}

// MARK: - Domain <-> LocalScheduleOverride 互转

extension LocalScheduleOverride {
    /// 将 Domain 层的 ScheduleOverride 转换为 SwiftData 持久化对象
    static func from(_ override: ScheduleOverride) throws -> LocalScheduleOverride {
        let actionData = try JSONEncoder().encode(override.action)
        return LocalScheduleOverride(
            id: override.id,
            scheduleID: override.scheduleID,
            targetDate: override.targetDate,
            actionData: actionData
        )
    }

    /// 将 SwiftData 持久化对象还原为 Domain 层的 ScheduleOverride 值类型
    func toDomain() throws -> ScheduleOverride {
        let action = try JSONDecoder().decode(ScheduleOverride.Action.self, from: actionData)
        return ScheduleOverride(
            id: id,
            scheduleID: scheduleID,
            targetDate: targetDate,
            action: action
        )
    }
}
