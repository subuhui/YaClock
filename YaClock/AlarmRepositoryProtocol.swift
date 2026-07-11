// MARK: - Domain Layer
import Foundation

/// 仓储层抽象：聚合持久化（SwiftData）与调度（AlarmKit）操作。
/// UseCase 依赖此协议，便于单元测试时 Mock。
@MainActor
protocol AlarmRepositoryProtocol: AnyObject {
    // MARK: 状态
    var systemAlarms: [SystemAlarmInfo] { get }
    var isAuthorized: Bool { get }

    // MARK: 持久化
    func save(_ entity: AlarmEntity) throws
    func delete(id: UUID) throws

    // MARK: 调度
    func scheduleAlarm(_ entity: AlarmEntity) async throws
    func cancelAlarm(id: UUID) async throws

    // MARK: 权限
    func requestAuthorization() async -> Bool
    func checkAuthorization()
}
