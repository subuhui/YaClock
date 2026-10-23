// @Author subuhui
// @Date 2026/7/12 10:49
// @Description 系统级闹钟调度的协议抽象，隔离 AlarmKit 与模拟器内存模拟两种实现

import Foundation

/// 系统级闹钟调度的抽象协议
/// 通过协议隔离真机 AlarmKit 与模拟器内存模拟，确保业务逻辑不依赖具体平台能力
protocol AlarmScheduler: Sendable {
    func activeIDs() async throws -> Set<UUID>
    var permission: AlarmPermission { get }
    func requestPermission() async throws -> AlarmPermission
    /// 调度一个具体的闹铃实例到系统
    /// - Parameter occurrence: 需要下发的闹铃实例
    func schedule(_ occurrence: AlarmOccurrence) async throws

    /// 取消一个已调度的闹铃实例
    /// - Parameter id: 闹铃实例的唯一 ID
    func cancel(id: UUID) async throws

    /// 获取当前系统队列中所有已调度的闹铃 ID 集合
    /// - Returns: 已调度的闹铃 UUID 集合
    func scheduledIDs() async throws -> Set<UUID>
}

/// 未实现权限接口的测试调度器默认视为模拟环境。
enum AlarmPermission: String, Sendable {
    case notDetermined = "尚未授权", denied = "已拒绝", authorized = "已授权", simulated = "模拟模式"
}

extension AlarmScheduler {
    func activeIDs() async throws -> Set<UUID> { [] }
    var permission: AlarmPermission { .simulated }
    func requestPermission() async throws -> AlarmPermission { .simulated }
}
