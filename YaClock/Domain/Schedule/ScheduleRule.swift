// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 表达闹钟作息重复规则的枚举类型，支持单次、每周重复、调休重复、大小周、轮班周期

import Foundation

/// 大小周交替轮替类型
public enum WeekType: String, Codable, Sendable {
    /// A周（如大周）
    case weekA
    /// B周（如小周）
    case weekB
}

/// 单次不重复响铃规则
public struct OnceRule: Codable, Hashable, Sendable {
    /// 唯一确定的响铃具体日期
    public let date: Date
    
    /// 初始化单次不重复规则
    /// - Parameter date: 响铃的特定日期
    public init(date: Date) {
        self.date = date
    }
}

/// 普通每周重复规则
public struct WeeklyRule: Codable, Hashable, Sendable {
    /// 重复响铃的星期，1 代表周日，2 代表周一，... 7 代表周六
    public let repeatDays: [Int]
    
    /// 初始化每周重复规则
    /// - Parameter repeatDays: 响铃的星期数组 (1-7)
    public init(repeatDays: [Int]) {
        self.repeatDays = repeatDays
    }
}

/// 中国法定节假日和调休的应对策略
public enum ChineseWorkdayPolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    /// 调休模式：遇到法定假节日跳过（不响），遇到补班日即使是周末也会响
    case followHoliday
    /// 只跳假节日模式：遇到法定节假日跳过（不响），但补班日如果不符合 repeatDays 的规律则依然不响
    case skipHoliday
    /// 忽略法定节假日模式：如同普通星期重复，忽略一切法定假节日和补班
    case ignoreHoliday

    /// 唯一标识符
    public var id: String { rawValue }
}

/// 中国法定节假日调休重复规则
public struct ChineseWorkdayRule: Codable, Hashable, Sendable {
    /// 应对国家节假日调休政策的策略
    public let policy: ChineseWorkdayPolicy
    
    /// 基础的重复星期设定（如周一至周五响）
    public let repeatDays: [Int]
    
    /// 初始化中国法定节假日调休重复规则
    /// - Parameters:
    ///   - policy: 节假日应对策略
    ///   - repeatDays: 基础重复星期
    public init(policy: ChineseWorkdayPolicy, repeatDays: [Int]) {
        self.policy = policy
        self.repeatDays = repeatDays
    }
}

/// 大小周交替重复规则
public struct AlternatingWeeksRule: Codable, Hashable, Sendable {
    /// 用于推算周数的锚点基准日期
    public let anchorDate: Date
    
    /// 锚点日期所在那一周的周类型（A周或B周）
    public let anchorWeekType: WeekType
    
    /// A周的响铃星期规则
    public let weekAWorkdays: [Int]
    
    /// B周的响铃星期规则
    public let weekBWorkdays: [Int]
    
    /// 初始化大小周规则
    /// - Parameters:
    ///   - anchorDate: 锚点日期
    ///   - anchorWeekType: 锚点所在周的周类型
    ///   - weekAWorkdays: A周响铃星期
    ///   - weekBWorkdays: B周响铃星期
    public init(anchorDate: Date, anchorWeekType: WeekType, weekAWorkdays: [Int], weekBWorkdays: [Int]) {
        self.anchorDate = anchorDate
        self.anchorWeekType = anchorWeekType
        self.weekAWorkdays = weekAWorkdays
        self.weekBWorkdays = weekBWorkdays
    }
}

/// 轮班周期中的单个工作日定义
public struct CycleDay: Codable, Hashable, Sendable {
    /// 周期这一天的名称，如“白班”、“夜班”、“休息”等
    public let name: String
    
    /// 这一天是否为工作日
    public let isWorking: Bool
    
    /// 这一天是否需要闹钟响铃
    public let isRinging: Bool
    
    /// 若这一天有特殊的响铃时间覆盖，在此处定义；否则使用作息表的默认时间
    public let timeOverride: LocalTime?
    
    /// 初始化轮班周期中的单日定义
    /// - Parameters:
    ///   - name: 日期名称描述
    ///   - isWorking: 是否工作
    ///   - isRinging: 是否响铃
    ///   - timeOverride: 临时覆盖的响铃时间
    public init(name: String, isWorking: Bool, isRinging: Bool, timeOverride: LocalTime? = nil) {
        self.name = name
        self.isWorking = isWorking
        self.isRinging = isRinging
        self.timeOverride = timeOverride
    }
}

/// 自定义轮班周期循环规则（如“前三天响，后一天休息”或“白白夜夜休休”）
public struct CycleRule: Codable, Hashable, Sendable {
    /// 循环周期起跑的锚点基准日期
    public let anchorDate: Date
    
    /// 一个循环周期的天数列表定义
    public let cycleDays: [CycleDay]
    
    /// 初始化轮班循环规则
    /// - Parameters:
    ///   - anchorDate: 锚点日期
    ///   - cycleDays: 周期内每天的配置
    public init(anchorDate: Date, cycleDays: [CycleDay]) {
        self.anchorDate = anchorDate
        self.cycleDays = cycleDays
    }
}

/// 统一封装作息重复规则的关联值枚举
public enum ScheduleRule: Codable, Hashable, Sendable {
    /// 单次响铃
    case once(OnceRule)
    /// 每周普通重复
    case weekly(WeeklyRule)
    /// 中国法定节假日调休重复
    case chineseWorkday(ChineseWorkdayRule)
    /// 大小周交替重复
    case alternatingWeeks(AlternatingWeeksRule)
    /// 自定义周期轮班重复
    case cycle(CycleRule)
}
