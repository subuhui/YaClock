// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 表达闹钟铃声配置的值类型，支持系统内置和用户导入的铃声

import Foundation

/// 表达闹钟铃声的值类型
public struct AlarmSound: Codable, Hashable, Sendable {
    /// 铃声的类型划分
    public enum SoundType: String, Codable, Sendable {
        /// 系统自带的默认铃声
        case system
        /// 用户导入或录制的自定义铃声
        case custom
    }
    
    /// 铃声的文件名称或标识符
    public let name: String
    
    /// 铃声的来源类型
    public let type: SoundType
    
    /// 初始化铃声配置
    /// - Parameters:
    ///   - name: 铃声名称
    ///   - type: 铃声类型，默认为系统自带
    public init(name: String, type: SoundType = .system) {
        self.name = name
        self.type = type
    }
    
    /// 默认系统铃声的便捷定义
    public static let `default` = AlarmSound(name: "default", type: .system)
}
