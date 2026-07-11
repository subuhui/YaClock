// MARK: - Domain Layer · UseCase
import Foundation

/// 切换闹钟启用/禁用状态：更新持久化 → 调度或取消。
@MainActor
struct ToggleAlarmUseCase {
    let repository: any AlarmRepositoryProtocol

    func execute(alarm: AlarmEntity, isEnabled: Bool) async throws {
        var updated = alarm
        updated.isEnabled = isEnabled
        try repository.save(updated)

        if isEnabled {
            try? await repository.cancelAlarm(id: alarm.id)
            try await repository.scheduleAlarm(updated)
        } else {
            try? await repository.cancelAlarm(id: alarm.id)
        }
    }
}
