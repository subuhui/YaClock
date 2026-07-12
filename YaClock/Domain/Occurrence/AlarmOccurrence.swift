// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 表达具体的闹铃响铃实例，用于对账与实际的 AlarmKit 调度下发

import Foundation
import CryptoKit

/// 表达一个即将被调度响铃的具体闹铃实例
public struct AlarmOccurrence: Identifiable, Codable, Hashable, Sendable {
    /// 闹铃实例的唯一且稳定的 ID（由 generateStableID 根据 scheduleID 和 fireDate 唯一推导）
    public let id: UUID
    
    /// 触发该实例的源头作息表 ID
    public let scheduleID: UUID
    
    /// 具体的响铃时间点（时、分部分由作息规则决定，秒部分通常为 0）
    public let fireDate: Date
    
    /// 响铃时展示的标签文字描述
    public let label: String
    
    /// 响铃时播放的铃声
    public let sound: AlarmSound
    
    /// 贪睡功能的配置
    public let snooze: SnoozeConfiguration

    /// 初始化闹钟响铃实例
    /// - Parameters:
    ///   - id: 唯一的稳定 ID
    ///   - scheduleID: 源作息 ID
    ///   - fireDate: 响铃具体时刻
    ///   - label: 闹钟标签
    ///   - sound: 铃声配置
    ///   - snooze: 贪睡配置
    public init(
        id: UUID,
        scheduleID: UUID,
        fireDate: Date,
        label: String,
        sound: AlarmSound,
        snooze: SnoozeConfiguration
    ) {
        self.id = id
        self.scheduleID = scheduleID
        self.fireDate = fireDate
        self.label = label
        self.sound = sound
        self.snooze = snooze
    }

    /// 根据作息表 ID 和响铃具体时间计算生成一个稳定的唯一 UUID。
    /// 该算法确保同一个作息在同一响铃时刻总是推导产生出相同的 UUID。
    /// - Parameters:
    ///   - scheduleID: 作息表 ID
    ///   - fireDate: 具体的响铃时刻
    /// - Returns: 稳定的 UUID 实例
    public static func generateStableID(scheduleID: UUID, fireDate: Date) -> UUID {
        // 将时间标准化为秒级时间戳，丢弃可能存在的微秒，保证精度对齐
        let seconds = Int(fireDate.timeIntervalSince1970)
        let key = "\(scheduleID.uuidString.lowercased())_\(seconds)"
        guard let data = key.data(using: .utf8) else {
            fatalError("无法将 stable ID 键转换为 UTF-8 数据")
        }
        
        let digest = SHA256.hash(data: data)
        var bytes = Array(digest.prefix(16))
        
        // 按照 RFC 4122 标准规范化设置版本位和变体位，使其符合合法的 UUID 标准
        // 设置版本位为 5 (基于 SHA-1/SHA-256 的散列命名空间)
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        // 设置变体位为 RFC 4122 规范的 10xx
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        
        let uuidTuple = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidTuple)
    }
}
