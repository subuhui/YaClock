// MARK: - Domain Layer · UseCase
import Foundation

/// 新建或更新一个闹钟：持久化 → cancel 旧调度 → 重新调度。
/// 封装了 schedule(id:) 不支持覆盖已有闹钟的修复逻辑。
@MainActor
struct SaveAlarmUseCase {
    let repository: any AlarmRepositoryProtocol

    func execute(_ entity: AlarmEntity) async throws {
        // 1. 持久化（新增 or 更新）
        try repository.save(entity)

        // 2. cancel-then-schedule 模式：
        //    - schedule(id:) 只能新建，对已有 ID 直接调用会报 Code=0
        //    - cancel 在 ID 不存在时也会抛错（新建场景），故用 try? 静默忽略
        if entity.isEnabled {
            try? await repository.cancelAlarm(id: entity.id)
            try await repository.scheduleAlarm(entity)
        } else {
            try? await repository.cancelAlarm(id: entity.id)
        }
    }
}
