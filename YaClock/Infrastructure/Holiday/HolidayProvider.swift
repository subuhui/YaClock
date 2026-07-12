// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 提供中国法定节假日与调休补班数据的查询服务（内置2026年数据）

import Foundation

/// 节假日的分类属性
public enum HolidayType: Equatable, Hashable, Sendable {
    /// 法定假期（不上班，如国庆假、春节假）
    case holiday(name: String)
    /// 法定补班日（原为周末，但因调休需要补班）
    case workday(reason: String)
}

/// 节假日数据提供者，内置 2026 年中国的法定节假日与补班数据
public struct HolidayProvider: Sendable {
    
    /// 年-月-日元组的哈希结构，用来作为静态字典的 Key，避免格式化 String 带来的性能开销
    private struct DateKey: Hashable, Sendable {
        let year: Int
        let month: Int
        let day: Int
    }
    
    /// 内置的 2026 年假期及补班数据映射字典
    private static let holidayMap: [DateKey: HolidayType] = {
        var map = [DateKey: HolidayType]()
        
        // 辅助函数快速添加
        func addHoliday(_ year: Int, _ month: Int, _ day: Int, name: String) {
            map[DateKey(year: year, month: month, day: day)] = .holiday(name: name)
        }
        
        func addWorkday(_ year: Int, _ month: Int, _ day: Int, reason: String) {
            map[DateKey(year: year, month: month, day: day)] = .workday(reason: reason)
        }
        
        // --- 2026 年法定节假日与补班数据初始化 ---
        
        // 1. 元旦 (1月1日)
        addHoliday(2026, 1, 1, name: "元旦")
        
        // 2. 春节 (2月17日至2月24日放假；2月8日、2月28日补班)
        addHoliday(2026, 2, 17, name: "除夕")
        addHoliday(2026, 2, 18, name: "春节")
        addHoliday(2026, 2, 19, name: "春节")
        addHoliday(2026, 2, 20, name: "春节")
        addHoliday(2026, 2, 21, name: "春节")
        addHoliday(2026, 2, 22, name: "春节")
        addHoliday(2026, 2, 23, name: "春节")
        addHoliday(2026, 2, 24, name: "春节")
        addWorkday(2026, 2, 8, reason: "春节调休补班")
        addWorkday(2026, 2, 28, reason: "春节调休补班")
        
        // 3. 清明节 (4月4日至4月6日放假)
        addHoliday(2026, 4, 4, name: "清明节")
        addHoliday(2026, 4, 5, name: "清明节")
        addHoliday(2026, 4, 6, name: "清明节")
        
        // 4. 劳动节 (5月1日至5月5日放假；4月26日、5月10日补班)
        addHoliday(2026, 5, 1, name: "劳动节")
        addHoliday(2026, 5, 2, name: "劳动节")
        addHoliday(2026, 5, 3, name: "劳动节")
        addHoliday(2026, 5, 4, name: "劳动节")
        addHoliday(2026, 5, 5, name: "劳动节")
        addWorkday(2026, 4, 26, reason: "劳动节调休补班")
        addWorkday(2026, 5, 10, reason: "劳动节调休补班")
        
        // 5. 端午节 (6月14日至6月16日放假；6月13日补班)
        addHoliday(2026, 6, 14, name: "端午节")
        addHoliday(2026, 6, 15, name: "端午节")
        addHoliday(2026, 6, 16, name: "端午节")
        addWorkday(2026, 6, 13, reason: "端午节调休补班")
        
        // 6. 中秋节 (9月25日至9月27日放假)
        addHoliday(2026, 9, 25, name: "中秋节")
        addHoliday(2026, 9, 26, name: "中秋节")
        addHoliday(2026, 9, 27, name: "中秋节")
        
        // 7. 国庆节 (10月1日至10月7日放假；9月27日与10月10日补班)
        addHoliday(2026, 10, 1, name: "国庆节")
        addHoliday(2026, 10, 2, name: "国庆节")
        addHoliday(2026, 10, 3, name: "国庆节")
        addHoliday(2026, 10, 4, name: "国庆节")
        addHoliday(2026, 10, 5, name: "国庆节")
        addHoliday(2026, 10, 6, name: "国庆节")
        addHoliday(2026, 10, 7, name: "国庆节")
        addWorkday(2026, 9, 27, reason: "国庆节调休补班")
        addWorkday(2026, 10, 10, reason: "国庆节调休补班")
        
        return map
    }()
    
    /// 初始化方法
    public init() {}
    
    /// 检查指定日期的节假日状态
    /// - Parameter date: 目标日期
    /// - Returns: 若这一天是法定假期或法定补班日，返回对应的 HolidayType；否则返回 nil
    public func checkHoliday(on date: Date) -> HolidayType? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        let key = DateKey(year: year, month: month, day: day)
        return Self.holidayMap[key]
    }
}
