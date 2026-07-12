// @Author subuhui
// @Date 2026/7/12 10:49
// @Description 内存模拟闹钟调度器，用于模拟器和低版本系统的安全降级，维护虚拟调度队列

import Foundation

/// 模拟器/低版本系统的内存闹钟调度实现
/// 在无法调用 AlarmKit 的环境下（模拟器、iOS 26以下），通过内存数组模拟系统调度队列
final class InMemoryAlarmScheduler: AlarmScheduler {

    /// 用于保护内存队列并发访问的 Actor
    private actor Storage {
        /// 已虚拟调度的闹铃集合，key 为闹铃 ID
        var scheduledAlarms: [UUID: AlarmOccurrence] = [:]

        /// 虚拟调度一个闹铃实例（幂等：同 ID 会覆盖旧记录）
        func schedule(_ occurrence: AlarmOccurrence) {
            scheduledAlarms[occurrence.id] = occurrence
        }

        /// 从虚拟队列中移除一个闹铃
        func cancel(id: UUID) {
            scheduledAlarms.removeValue(forKey: id)
        }

        /// 返回当前虚拟队列中所有已调度的闹铃 ID
        func scheduledIDs() -> Set<UUID> {
            Set(scheduledAlarms.keys)
        }
    }

    private let storage = Storage()

    /// 初始化内存调度器
    init() {}

    /// 向内存虚拟队列中添加一个闹铃实例
    func schedule(_ occurrence: AlarmOccurrence) async throws {
        await storage.schedule(occurrence)
    }

    /// 从内存虚拟队列中移除一个闹铃实例
    func cancel(id: UUID) async throws {
        await storage.cancel(id: id)
    }

    /// 返回内存虚拟队列中所有已调度的闹铃 ID
    func scheduledIDs() async throws -> Set<UUID> {
        await storage.scheduledIDs()
    }
}
