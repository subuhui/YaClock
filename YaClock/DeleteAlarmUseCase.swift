// MARK: - Domain Layer · UseCase
import Foundation

/// 删除闹钟：先取消系统调度，再从持久化层删除。
@MainActor
struct DeleteAlarmUseCase {
    let repository: any AlarmRepositoryProtocol

    func execute(id: UUID) async throws {
        try await repository.cancelAlarm(id: id)
        try repository.delete(id: id)
    }
}
