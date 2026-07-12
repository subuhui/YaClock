// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 封装小时与分钟的值类型，用于无日期关联的作息时间表达

import Foundation

/// 表示一天中具体时间（时与分）的结构体，与具体日期无关
public struct LocalTime: Codable, Hashable, Sendable, Comparable {
    /// 小时，范围为 0...23
    public let hour: Int
    
    /// 分钟，范围为 0...59
    public let minute: Int
    
    /// 初始化方法，并验证输入的合法性
    /// - Parameters:
    ///   - hour: 小时数 (0-23)
    ///   - minute: 分钟数 (0-59)
    public init(hour: Int, minute: Int) {
        precondition((0...23).contains(hour), "小时必须在 0 到 23 之间")
        precondition((0...59).contains(minute), "分钟必须在 0 到 59 之间")
        self.hour = hour
        self.minute = minute
    }
    
    /// 比较两个 LocalTime 的先后顺序
    /// - Parameters:
    ///   - lhs: 比较的左侧时间
    ///   - rhs: 比较的右侧时间
    /// - Returns: 当左侧时间早于右侧时间时返回 true
    public static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        if lhs.hour != rhs.hour {
            return lhs.hour < rhs.hour
        }
        return lhs.minute < rhs.minute
    }
}
