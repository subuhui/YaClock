// @Author subuhui
// @Date 2026/7/12 10:21
// @Description [Test] 验证 YaClock 规则引擎在周重复、节假日调休、大小周、轮班周期以及临时覆盖下的计算正确性

import Testing
import Foundation
@testable import YaClock

struct RuleEngineTests {
    // 助手函数，方便构造 Date
    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps)!
    }
    
    @Test func testWeeklyRule() async throws {
        // 设为忽略节假日，以确保基础每周重复规则不受全局设置干扰
        UserDefaults.standard.set(ChineseWorkdayPolicy.ignoreHoliday.rawValue, forKey: "defaultHolidayPolicy")
        
        let engine = RuleEngine()
        let holidays = HolidayProvider()
        
        let schedule = Schedule(
            name: "每周二四响铃",
            time: LocalTime(hour: 7, minute: 30),
            rule: .weekly(WeeklyRule(repeatDays: [3, 5])) // 3 = 周二, 5 = 周四
        )
        
        // 查询 2026年1月1日(周四) 到 2026年1月7日(周三)
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 7)
        
        let occurrences = engine.generateOccurrences(
            for: schedule,
            overrides: [],
            holidays: holidays,
            in: start...end
        )
        
        // 2026年1月1日(周四) -> 应响
        // 2026年1月6日(周二) -> 应响
        #expect(occurrences.count == 2)
        #expect(Calendar.current.component(.weekday, from: occurrences[0].fireDate) == 5)
        #expect(Calendar.current.component(.weekday, from: occurrences[1].fireDate) == 3)
    }
    
    @Test func testWeeklyRuleWithGlobalHolidayPolicy() async throws {
        // [Test] 验证在全局设定“跳过节假日”时，普通的每周重复闹钟在法定假期中能被自动过滤（不响）
        UserDefaults.standard.set(ChineseWorkdayPolicy.skipHoliday.rawValue, forKey: "defaultHolidayPolicy")
        
        let engine = RuleEngine()
        let holidays = HolidayProvider()
        
        let schedule = Schedule(
            name: "每周工作日闹钟",
            time: LocalTime(hour: 7, minute: 0),
            rule: .weekly(WeeklyRule(repeatDays: [2, 3, 4, 5, 6])) // 周一至五
        )
        
        // 2026年元旦：1月1日(周四，放假)
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 1)
        
        let occurrences = engine.generateOccurrences(
            for: schedule,
            overrides: [],
            holidays: holidays,
            in: start...end
        )
        
        // 元旦这天应被过滤跳过
        #expect(occurrences.isEmpty)
    }
    
    @Test func testChineseWorkdayRule() async throws {
        let engine = RuleEngine()
        let holidays = HolidayProvider()
        
        let schedule = Schedule(
            name: "节假日调休闹钟",
            time: LocalTime(hour: 8, minute: 0),
            rule: .chineseWorkday(ChineseWorkdayRule(policy: .followHoliday, repeatDays: [2, 3, 4, 5, 6])) // 周一至周五响
        )
        
        // 2026年国庆节附近：9月27日(周日，国庆补班)，10月1日(周四，国庆节放假)
        // 我们查 2026-09-25 到 2026-10-05 期间
        let start = makeDate(year: 2026, month: 9, day: 25)
        let end = makeDate(year: 2026, month: 10, day: 5)
        
        let occurrences = engine.generateOccurrences(
            for: schedule,
            overrides: [],
            holidays: holidays,
            in: start...end
        )
        
        // 9-25(周五, 响), 9-27(周日补班, 响), 9-28至9-30(周一至三, 响), 10-1至10-3(放假, 不响), 10-4(周日, 本来就不响), 10-5(放假, 不响)
        // 预期的响铃日期集合：
        // - 9月25日 08:00
        // - 9月27日 08:00 (补班)
        // - 9月28日 08:00
        // - 9月29日 08:00
        // - 9月30日 08:00
        let ringDates = occurrences.map { calendarDateTuple(from: $0.fireDate) }
        #expect(ringDates.contains(where: { $0 == (2026, 9, 25) }))
        #expect(ringDates.contains(where: { $0 == (2026, 9, 27) }))
        #expect(ringDates.contains(where: { $0 == (2026, 9, 28) }))
        #expect(ringDates.contains(where: { $0 == (2026, 9, 29) }))
        #expect(ringDates.contains(where: { $0 == (2026, 9, 30) }))
        
        // 确认国庆期间 10-1 到 10-3 以及 10-5 确实没有响铃
        #expect(!ringDates.contains(where: { $0 == (2026, 10, 1) }))
        #expect(!ringDates.contains(where: { $0 == (2026, 10, 2) }))
        #expect(!ringDates.contains(where: { $0 == (2026, 10, 5) }))
    }
    
    @Test func testAlternatingWeeksRule() async throws {
        let engine = RuleEngine()
        let holidays = HolidayProvider()
        
        // 锚点定在 2026-01-05（周一），设定其为 A周。
        // A周：周一响，周六响
        // B周：周一响，周六不响
        let anchorDate = makeDate(year: 2026, month: 1, day: 5)
        let rule = AlternatingWeeksRule(
            anchorDate: anchorDate,
            anchorWeekType: .weekA,
            weekAWorkdays: [2, 7], // 2 = 周一, 7 = 周六
            weekBWorkdays: [2]
        )
        let schedule = Schedule(
            name: "大小周闹钟",
            time: LocalTime(hour: 9, minute: 0),
            rule: .alternatingWeeks(rule)
        )
        
        // 查询 2026年1月5日(周一，A周) 到 2026年1月18日(周日，B周结束)
        let start = makeDate(year: 2026, month: 1, day: 5)
        let end = makeDate(year: 2026, month: 1, day: 18)
        
        let occurrences = engine.generateOccurrences(
            for: schedule,
            overrides: [],
            holidays: holidays,
            in: start...end
        )
        
        let ringDates = occurrences.map { calendarDateTuple(from: $0.fireDate) }
        
        // A周周一 (1月5日) 响，A周周六 (1月10日) 响
        #expect(ringDates.contains(where: { $0 == (2026, 1, 5) }))
        #expect(ringDates.contains(where: { $0 == (2026, 1, 10) }))
        
        // B周周一 (1月12日) 响，B周周六 (1月17日) 不响
        #expect(ringDates.contains(where: { $0 == (2026, 1, 12) }))
        #expect(!ringDates.contains(where: { $0 == (2026, 1, 17) }))
    }
    
    @Test func testCycleRule() async throws {
        let engine = RuleEngine()
        let holidays = HolidayProvider()
        
        // 轮班周期：白班(响)，夜班(响)，休息(不响)
        let cycleDays = [
            CycleDay(name: "白班", isWorking: true, isRinging: true),
            CycleDay(name: "夜班", isWorking: true, isRinging: true),
            CycleDay(name: "休息", isWorking: false, isRinging: false)
        ]
        // 锚点定在 2026-01-01 (周四)
        let anchor = makeDate(year: 2026, month: 1, day: 1)
        let schedule = Schedule(
            name: "轮班闹钟",
            time: LocalTime(hour: 8, minute: 30),
            rule: .cycle(CycleRule(anchorDate: anchor, cycleDays: cycleDays))
        )
        
        // 查询 1月1日(周四) 到 1月6日(周二)
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 6)
        
        let occurrences = engine.generateOccurrences(
            for: schedule,
            overrides: [],
            holidays: holidays,
            in: start...end
        )
        
        let ringDates = occurrences.map { calendarDateTuple(from: $0.fireDate) }
        
        // 1-1：白班 -> 响
        // 1-2：夜班 -> 响
        // 1-3：休息 -> 不响
        // 1-4：白班 -> 响
        // 1-5：夜班 -> 响
        // 1-6：休息 -> 不响
        #expect(ringDates.contains(where: { $0 == (2026, 1, 1) }))
        #expect(ringDates.contains(where: { $0 == (2026, 1, 2) }))
        #expect(!ringDates.contains(where: { $0 == (2026, 1, 3) }))
        #expect(ringDates.contains(where: { $0 == (2026, 1, 4) }))
        #expect(ringDates.contains(where: { $0 == (2026, 1, 5) }))
        #expect(!ringDates.contains(where: { $0 == (2026, 1, 6) }))
    }
    
    @Test func testScheduleOverride() async throws {
        let engine = RuleEngine()
        let holidays = HolidayProvider()
        
        let scheduleID = UUID()
        let schedule = Schedule(
            id: scheduleID,
            name: "普通作息",
            time: LocalTime(hour: 7, minute: 0),
            rule: .weekly(WeeklyRule(repeatDays: [2, 3, 4, 5, 6])) // 周一至五
        )
        
        // 2026-01-05 (周一) 设定为 skip
        // 2026-01-06 (周二) 设定为 changeTime 为 09:00
        // 2026-01-10 (周六) 设定为 forceWorking (强制响)
        let skipOverride = ScheduleOverride(scheduleID: scheduleID, targetDate: makeDate(year: 2026, month: 1, day: 5), action: .skip)
        let changeTimeOverride = ScheduleOverride(scheduleID: scheduleID, targetDate: makeDate(year: 2026, month: 1, day: 6), action: .changeTime(LocalTime(hour: 9, minute: 0)))
        let forceOverride = ScheduleOverride(scheduleID: scheduleID, targetDate: makeDate(year: 2026, month: 1, day: 10), action: .forceWorking)
        
        let start = makeDate(year: 2026, month: 1, day: 5)
        let end = makeDate(year: 2026, month: 1, day: 11)
        
        let occurrences = engine.generateOccurrences(
            for: schedule,
            overrides: [skipOverride, changeTimeOverride, forceOverride],
            holidays: holidays,
            in: start...end
        )
        
        // 1-5 (周一, 本来响, 被 skip) -> 不响
        #expect(!occurrences.contains(where: { calendarDateTuple(from: $0.fireDate) == (2026, 1, 5) }))
        
        // 1-06 (周二, 修改时间为 9:00) -> 响且时间是 9:00
        let tuesdayOccurrence = occurrences.first { calendarDateTuple(from: $0.fireDate) == (2026, 1, 6) }
        #expect(tuesdayOccurrence != nil)
        #expect(Calendar.current.component(.hour, from: tuesdayOccurrence!.fireDate) == 9)
        #expect(Calendar.current.component(.minute, from: tuesdayOccurrence!.fireDate) == 0)
        
        // 1-10 (周六, 本来不响, 强制响) -> 响且时间是 7:00
        let saturdayOccurrence = occurrences.first { calendarDateTuple(from: $0.fireDate) == (2026, 1, 10) }
        #expect(saturdayOccurrence != nil)
        #expect(Calendar.current.component(.hour, from: saturdayOccurrence!.fireDate) == 7)
        #expect(Calendar.current.component(.minute, from: saturdayOccurrence!.fireDate) == 0)
    }
    
    // 提取年月日的助手函数
    private func calendarDateTuple(from date: Date) -> (Int, Int, Int) {
        let comp = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (comp.year!, comp.month!, comp.day!)
    }
}
