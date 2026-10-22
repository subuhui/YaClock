// @Author subuhui
// @Date 2026/7/12 12:15
// @Description AlarmKit 真机调度实现，符合 AlarmKit 框架 API 规范

import Foundation
import SwiftUI
import AlarmKit

/// 基于 AlarmKit 的真机闹钟调度实现
/// 注意：AlarmKit 只支持 iOS 26+ 真机，此类不应在模拟器中实例化
@available(iOS 26.0, *)
final class AlarmKitScheduler: AlarmScheduler {

    /// 初始化 AlarmKit 调度器
    init() {}

    /// 将 AlarmOccurrence 注册为 AlarmKit 系统闹钟
    /// - 此处必须使用 cancel → schedule 的更新模式，直接对已存在 ID 调用 schedule 会触发 Code=0 错误
    func schedule(_ occurrence: AlarmOccurrence) async throws {
        // 先尝试取消，如果 ID 不存在则静默忽略
        try? AlarmManager.shared.cancel(id: occurrence.id)

        // 构造 AlarmPresentation.Alert
        let alertPresentation = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: occurrence.label),
            stopButton: AlarmButton(text: "停止", textColor: .white, systemImageName: "xmark.circle.fill"),
            secondaryButton: occurrence.snooze.isEnabled
                ? AlarmButton(text: "贪睡", textColor: .white, systemImageName: "zzz") : nil,
            secondaryButtonBehavior: occurrence.snooze.isEnabled ? .countdown : nil
        )

        // 构造 AlarmAttributes
        let attributes = AlarmAttributes<EmptyMetadata>(
            presentation: AlarmPresentation(
                alert: alertPresentation,
                countdown: occurrence.snooze.isEnabled
                    ? AlarmPresentation.Countdown(title: "贪睡中") : nil
            ),
            tintColor: .blue
        )

        // 构造固定时间响铃 Schedule
        let schedule = Alarm.Schedule.fixed(occurrence.fireDate)

        // 构造 AlarmConfiguration
        let configuration = AlarmManager.AlarmConfiguration<EmptyMetadata>(
            countdownDuration: occurrence.snooze.isEnabled
                ? Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(occurrence.snooze.durationMinutes) * 60)
                : nil,
            schedule: schedule,
            attributes: attributes
        )

        _ = try await AlarmManager.shared.schedule(id: occurrence.id, configuration: configuration)
    }

    /// 取消已调度的系统闹钟
    func cancel(id: UUID) async throws {
        try AlarmManager.shared.cancel(id: id)
    }

    /// 从 AlarmKit 系统队列中读取已调度的闹铃 ID 集合
    func scheduledIDs() async throws -> Set<UUID> {
        let alarms = try AlarmManager.shared.alarms
        return Set(alarms.map { $0.id })
    }
}
