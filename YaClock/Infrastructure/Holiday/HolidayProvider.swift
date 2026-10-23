import Foundation

public enum HolidayType: Equatable, Hashable, Sendable {
    case holiday(name: String)
    case workday(reason: String)
}

/// 按年导入完整数据；未覆盖的年份明确提示，规则仍按普通星期计算。
public struct HolidayDataset: Codable, Sendable {
    public struct Day: Codable, Sendable {
        let date: String
        let name: String
        let isWorkday: Bool
    }
    let year: Int
    let source: String
    let updatedAt: Date
    let days: [Day]
}

enum HolidayImportError: LocalizedError {
    case invalidData
    var errorDescription: String? { "节假日文件无效：请检查年份、来源、更新时间及日期（yyyy-MM-dd），日期不可重复。" }
}

public struct HolidayProvider: Sendable {
    static let storageKey = "holiday.datasets.v1"
    static let officialSource = "https://www.beijing.gov.cn/zhengce/zhengcefagui/202511/t20251104_4258873.html"

    public init() {}

    static var datasets: [HolidayDataset] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [builtIn] }
        // 只有通过 importData 验证并编码的内容能进入此存储。
        let imported = try! JSONDecoder().decode([HolidayDataset].self, from: data)
        return imported.contains(where: { $0.year == 2026 }) ? imported : [builtIn] + imported
    }

    static func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dataset = try decoder.decode(HolidayDataset.self, from: data)
        guard (1900...2200).contains(dataset.year),
              !dataset.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !dataset.days.isEmpty,
              Set(dataset.days.map(\.date)).count == dataset.days.count else { throw HolidayImportError.invalidData }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        for day in dataset.days {
            guard let date = formatter.date(from: day.date),
                  formatter.string(from: date) == day.date,
                  day.date.hasPrefix("\(dataset.year)-"), !day.name.isEmpty else { throw HolidayImportError.invalidData }
        }
        var updated = datasets.filter { $0.year != dataset.year }
        updated.append(dataset)
        UserDefaults.standard.set(try JSONEncoder().encode(updated), forKey: storageKey)
    }

    static func missingYears(in range: ClosedRange<Date>) -> [Int] {
        let calendar = Calendar.current
        let years = calendar.component(.year, from: range.lowerBound)...calendar.component(.year, from: range.upperBound)
        let available = Set(datasets.map(\.year))
        return years.filter { !available.contains($0) }
    }

    public func checkHoliday(on date: Date) -> HolidayType? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let key = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        guard let day = Self.datasets.first(where: { $0.year == c.year })?.days.first(where: { $0.date == key }) else { return nil }
        return day.isWorkday ? .workday(reason: day.name) : .holiday(name: day.name)
    }

    static let builtIn: HolidayDataset = {
        var days: [HolidayDataset.Day] = []
        func holiday(_ month: Int, _ range: ClosedRange<Int>, _ name: String) {
            days += range.map { .init(date: String(format: "2026-%02d-%02d", month, $0), name: name, isWorkday: false) }
        }
        func work(_ month: Int, _ day: Int, _ name: String) {
            days.append(.init(date: String(format: "2026-%02d-%02d", month, day), name: name, isWorkday: true))
        }
        holiday(1, 1...3, "元旦"); work(1, 4, "元旦补班")
        holiday(2, 15...23, "春节"); work(2, 14, "春节补班"); work(2, 28, "春节补班")
        holiday(4, 4...6, "清明节")
        holiday(5, 1...5, "劳动节"); work(5, 9, "劳动节补班")
        holiday(6, 19...21, "端午节")
        holiday(9, 25...27, "中秋节")
        holiday(10, 1...7, "国庆节"); work(9, 20, "国庆节补班"); work(10, 10, "国庆节补班")
        return HolidayDataset(year: 2026, source: officialSource,
            updatedAt: ISO8601DateFormatter().date(from: "2025-11-04T00:00:00Z")!, days: days)
    }()
}
