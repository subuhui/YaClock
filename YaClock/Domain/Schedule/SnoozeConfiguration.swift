// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 表达稍后提醒（贪睡功能）的开关与间隔时长的值类型

import Foundation

/// 表达闹钟稍后提醒（贪睡）规则的配置
public struct SnoozeConfiguration: Codable, Hashable, Sendable {
    /// 是否开启贪睡提醒功能
    public let isEnabled: Bool
    
    /// 贪睡的每次延迟时间间隔，单位为分钟
    public let durationMinutes: Int
    
    /// 初始化稍后提醒配置
    /// - Parameters:
    ///   - isEnabled: 是否启用贪睡功能
    ///   - durationMinutes: 延迟分钟数，若启用则必须大于等于 1
    public init(isEnabled: Bool, durationMinutes: Int = 9) {
        if isEnabled {
            precondition(durationMinutes >= 1, "贪睡延迟分钟数必须大于等于1分钟")
        }
        self.isEnabled = isEnabled
        self.durationMinutes = durationMinutes
    }
    
    /// 默认关闭贪睡的快捷配置
    public static let disabled = SnoozeConfiguration(isEnabled: false)
}
