// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 表达对某一天的特定作息规则进行单日临时覆盖的值类型

import Foundation

/// 表达单日临时性调整覆盖的值类型
public struct ScheduleOverride: Identifiable, Codable, Hashable, Sendable {
    /// 临时覆盖的具体行为动作
    public enum Action: Codable, Hashable, Sendable {
        /// 临时休息（即跳过当天的响铃）
        case skip
        /// 临时强行响铃工作（即忽略节假日或正常排班，在当天强制响铃）
        case forceWorking
        /// 临时修改当天的响铃时间
        case changeTime(LocalTime)
    }

    /// 唯一标识符
    public let id: UUID
    
    /// 被调整覆盖的目标作息表 ID
    public let scheduleID: UUID
    
    /// 调整生效的目标日期（其时、分、秒部分会在初始化时被标准化为当天的 00:00:00）
    public let targetDate: Date
    
    /// 具体的覆盖调整行为
    public var action: Action

    /// 初始化临时覆盖规则
    /// - Parameters:
    ///   - id: 唯一标识符，默认自动生成
    ///   - scheduleID: 作息表 ID
    ///   - targetDate: 生效的目标日期
    ///   - action: 覆盖动作
    public init(
        id: UUID = UUID(),
        scheduleID: UUID,
        targetDate: Date,
        action: Action
    ) {
        self.id = id
        self.scheduleID = scheduleID
        // 抹除时分秒，在入口对数据进行标准化，信任数据并防范时分秒不一致带来的对账 bug
        self.targetDate = Calendar.current.startOfDay(for: targetDate)
        self.action = action
    }
}
