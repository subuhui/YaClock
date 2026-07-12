// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 表达长期作息表的主实体模型，聚合时间、规则、铃声与贪睡配置

import Foundation

/// 长期作息配置主实体
public struct Schedule: Identifiable, Codable, Hashable, Sendable {
    /// 唯一标识符
    public let id: UUID
    
    /// 作息名称名称描述（如“工作日闹钟”、“大小周起床时间”）
    public var name: String
    
    /// 响铃的具体时间（时与分）
    public var time: LocalTime
    
    /// 作息的重复调度规则
    public var rule: ScheduleRule
    
    /// 作息所关联响铃的铃声
    public var sound: AlarmSound
    
    /// 稍后提醒（贪睡）的规则配置
    public var snooze: SnoozeConfiguration
    
    /// 该作息规则当前是否处于启用状态
    public var isEnabled: Bool
    
    /// 作息有效性的起始计算日期（默认从创建时刻起生效）
    public var startDate: Date
    
    /// 作息有效期的结束日期，若为 nil 则表示长期无限期生效
    public var endDate: Date?
    
    /// 初始化作息表主实体
    /// - Parameters:
    ///   - id: 唯一标识符，默认自动生成
    ///   - name: 作息名称
    ///   - time: 默认响铃时间
    ///   - rule: 调度规律
    ///   - sound: 闹钟铃声，默认使用系统 default
    ///   - snooze: 贪睡设置，默认禁用
    ///   - isEnabled: 启用状态，默认开启
    ///   - startDate: 生效起点，默认当前日期
    ///   - endDate: 结束时间，默认无限期
    public init(
        id: UUID = UUID(),
        name: String,
        time: LocalTime,
        rule: ScheduleRule,
        sound: AlarmSound = .default,
        snooze: SnoozeConfiguration = .disabled,
        isEnabled: Bool = true,
        startDate: Date = Date(),
        endDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.time = time
        self.rule = rule
        self.sound = sound
        self.snooze = snooze
        self.isEnabled = isEnabled
        self.startDate = startDate
        self.endDate = endDate
    }
}
