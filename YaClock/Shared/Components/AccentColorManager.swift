// @Author subuhui
// @Date 2026/7/12 10:49
// @Description 全局 Accent 配色管理器，支持预设主题与自定义 HSL 色彩，持久化到 UserDefaults

import SwiftUI

// MARK: - AccentPreset

/// 内置的 Accent 颜色预设主题
enum AccentPreset: String, CaseIterable, Identifiable {
    case auto     = "auto"
    case ocean    = "ocean"
    case forest   = "forest"
    case sunset   = "sunset"
    case violet   = "violet"
    case rose     = "rose"
    case mint     = "mint"
    case slate    = "slate"
    case midnight = "midnight"
    case custom   = "custom"

    var id: String { rawValue }

    /// 预设主题的中文显示名称
    var displayName: String {
        switch self {
        case .auto:     return "跟随系统"
        case .ocean:    return "深海"
        case .forest:   return "森林"
        case .sunset:   return "落日"
        case .violet:   return "紫光"
        case .rose:     return "玫瑰"
        case .mint:     return "薄荷"
        case .slate:    return "石板"
        case .midnight: return "午夜"
        case .custom:   return "自定义"
        }
    }

    /// 预设主题对应的 HSL 色彩值（hue 0-360, saturation 0-1, lightness 0-1）
    /// 自定义模式使用 AccentColorManager.customHSL 中存储的值
    var hsl: (hue: Double, saturation: Double, lightness: Double)? {
        switch self {
        case .auto:   return nil
        case .ocean:  return (hue: 205, saturation: 0.80, lightness: 0.50)
        case .forest: return (hue: 140, saturation: 0.55, lightness: 0.40)
        case .sunset: return (hue: 25,  saturation: 0.90, lightness: 0.55)
        case .violet: return (hue: 265, saturation: 0.75, lightness: 0.58)
        case .rose:   return (hue: 345, saturation: 0.80, lightness: 0.58)
        case .mint:   return (hue: 172, saturation: 0.82, lightness: 0.34)
        case .slate:  return (hue: 215, saturation: 0.19, lightness: 0.34)
        case .midnight: return (hue: 215, saturation: 0.25, lightness: 0.27)
        case .custom: return nil
        }
    }
}

// MARK: - AccentColorManager

/// 全局 Accent 配色状态管理器
/// 通过 @Observable 暴露给 SwiftUI 视图层，颜色选择持久化到 UserDefaults
@Observable
final class AccentColorManager {

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let preset = "accent.preset"
        static let customHue = "accent.custom.hue"
        static let customSaturation = "accent.custom.saturation"
        static let customLightness = "accent.custom.lightness"
    }

    /// 当前选择的主题预设
    var currentPreset: AccentPreset {
        didSet {
            UserDefaults.standard.set(currentPreset.rawValue, forKey: Keys.preset)
        }
    }

    /// 自定义模式下的色相（0-360）
    var customHue: Double {
        didSet { UserDefaults.standard.set(customHue, forKey: Keys.customHue) }
    }

    /// 自定义模式下的饱和度（0-1）
    var customSaturation: Double {
        didSet { UserDefaults.standard.set(customSaturation, forKey: Keys.customSaturation) }
    }

    /// 自定义模式下的亮度（0-1）
    var customLightness: Double {
        didSet { UserDefaults.standard.set(customLightness, forKey: Keys.customLightness) }
    }

    /// 当前生效的 Accent Color，供 SwiftUI 视图直接读取。支持亮暗色模式的自动转换。
    var color: Color {
        Color(uiColor: UIColor { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            switch self.currentPreset {
            case .auto:
                if #available(iOS 15.0, *) {
                    return UIColor.tintColor
                } else {
                    return isDark ? UIColor(Color(hex: "60A5FA")) : UIColor(Color(hex: "2563EB"))
                }
            case .ocean:
                return isDark ? UIColor(Color(hex: "60A5FA")) : UIColor(Color(hex: "2563EB"))
            case .forest:
                return isDark ? UIColor(Color(hex: "4ADE80")) : UIColor(Color(hex: "16A34A"))
            case .sunset:
                return isDark ? UIColor(Color(hex: "FB923C")) : UIColor(Color(hex: "EA580C"))
            case .violet:
                return isDark ? UIColor(Color(hex: "A78BFA")) : UIColor(Color(hex: "7C3AED"))
            case .rose:
                return isDark ? UIColor(Color(hex: "F472B6")) : UIColor(Color(hex: "DB2777"))
            case .mint:
                return isDark ? UIColor(Color(hex: "2DD4BF")) : UIColor(Color(hex: "0F9D8A"))
            case .slate:
                return isDark ? UIColor(Color(hex: "94A3B8")) : UIColor(Color(hex: "475569"))
            case .midnight:
                return isDark ? UIColor(Color(hex: "CBD5E1")) : UIColor(Color(hex: "334155"))
            case .custom:
                let h = self.customHue
                if isDark {
                    let s = max(0.60, min(0.80, self.customSaturation))
                    let l = max(0.65, min(0.80, self.customLightness))
                    return UIColor(Color(hue: h / 360.0, saturation: s, brightness: l))
                } else {
                    return UIColor(Color(hue: h / 360.0, saturation: self.customSaturation, brightness: self.customLightness))
                }
            }
        })
    }

    /// 当前 Accent 颜色的 10% 透明度版本，用于卡片轻染色
    var tintedOverlay: Color {
        color.opacity(0.10)
    }

    /// 初始化时从 UserDefaults 读取持久化的配置
    init() {
        let rawPreset = UserDefaults.standard.string(forKey: Keys.preset) ?? AccentPreset.ocean.rawValue
        self.currentPreset = AccentPreset(rawValue: rawPreset) ?? .ocean
        self.customHue = UserDefaults.standard.object(forKey: Keys.customHue) as? Double ?? 205.0
        self.customSaturation = UserDefaults.standard.object(forKey: Keys.customSaturation) as? Double ?? 0.80
        self.customLightness = UserDefaults.standard.object(forKey: Keys.customLightness) as? Double ?? 0.50
    }

    /// 切换到指定预设主题
    /// - Parameter preset: 要切换的预设
    func select(_ preset: AccentPreset) {
        currentPreset = preset
    }
}
