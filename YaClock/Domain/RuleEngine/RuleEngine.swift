// @Author subuhui
// @Date 2026/7/12 10:20
// @Description 作息响铃规则的计算引擎，支持周重复、节假日调休、大小周和轮班周期等算法，并应用单日覆盖调整

import Foundation

/// 闹钟作息规则的核心计算引擎
public struct RuleEngine {
    
    /// 初始化规则引擎
    public init() {}
    
    /// 常规滚动窗口之外，额外预排跨窗口休假结束后的闹钟，避免长假结束当天依赖后台唤醒。
    public func upcomingOccurrences(
        for schedule: Schedule, overrides: [ScheduleOverride], holidays: HolidayProvider,
        from now: Date, horizonDays: Int = 60, calendar: Calendar = .current
    ) -> [AlarmOccurrence] {
        let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now)!
        var occurrences = generateOccurrences(for: schedule, overrides: overrides, holidays: holidays, in: now...horizon, calendar: calendar)
        if let start = schedule.vacationStart, let end = schedule.vacationEnd,
           calendar.startOfDay(for: start) <= horizon, calendar.startOfDay(for: end) >= horizon {
            let resume = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
            let resumeEnd = calendar.date(byAdding: .day, value: horizonDays, to: resume)!
            occurrences += generateOccurrences(for: schedule, overrides: overrides, holidays: holidays, in: resume...resumeEnd, calendar: calendar)
        }
        return occurrences.sorted { $0.fireDate < $1.fireDate }
    }

    /// 根据指定的作息表、临时覆盖配置以及国家节假日数据，生成指定时间区间内的所有具体响铃实例
    /// - Parameters:
    ///   - schedule: 需要计算的长期作息表
    ///   - overrides: 针对该作息表的单日临时覆盖配置数组
    ///   - holidays: 节假日数据提供者
    ///   - dateRange: 需要生成实例的时间范围闭区间
    ///   - calendar: 进行日期计算所采用的日历，默认使用当前系统日历
    /// - Returns: 生成的具体响铃实例数组 [AlarmOccurrence]
    public func generateOccurrences(
        for schedule: Schedule,
        overrides: [ScheduleOverride],
        holidays: HolidayProvider,
        in dateRange: ClosedRange<Date>,
        calendar: Calendar = Calendar.current,
        holidayPolicy: ChineseWorkdayPolicy? = nil
    ) -> [AlarmOccurrence] {
        // 如果作息未启用，直接不生成任何响铃实例
        guard schedule.isEnabled else { return [] }
        
        var occurrences = [AlarmOccurrence]()
        
        // 将 dateRange 的起点和终点抹去时分秒，对齐到当天 00:00:00，避免边界时间错失
        let rangeStart = calendar.startOfDay(for: dateRange.lowerBound)
        let rangeEnd = calendar.startOfDay(for: dateRange.upperBound)
        
        var currentDate = rangeStart
        while currentDate <= rangeEnd {
            // 1. 作息有效期检验
            let scheduleStartDay = calendar.startOfDay(for: schedule.startDate)
            if currentDate < scheduleStartDay {
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
                continue
            }
            
            if let endDate = schedule.endDate {
                let scheduleEndDay = calendar.startOfDay(for: endDate)
                if currentDate > scheduleEndDay {
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                    currentDate = nextDate
                    continue
                }
            }
            
            // 2. 匹配该日期下可能存在的单日覆盖配置
            let dayOverride = overrides.first { calendar.isDate($0.targetDate, inSameDayAs: currentDate) }
            
            // 3. 计算在默认规则下该天是否响铃，以及默认响铃时间
            var isRingingByDefault = false
            var defaultRingTime = schedule.time
            
            switch schedule.rule {
            case .once(let rule):
                isRingingByDefault = calendar.isDate(rule.date, inSameDayAs: currentDate)
                
            case .weekly(let rule):
                let weekday = calendar.component(.weekday, from: currentDate)
                isRingingByDefault = rule.repeatDays.contains(weekday)
                
            case .chineseWorkday(let rule):
                let weekday = calendar.component(.weekday, from: currentDate)
                let isBaseMatch = rule.repeatDays.contains(weekday)
                
                if let holidayType = holidays.checkHoliday(on: currentDate) {
                    switch holidayType {
                    case .holiday:
                        // 遇到法定假期
                        switch rule.policy {
                        case .followHoliday, .skipHoliday:
                            isRingingByDefault = false // 放假跳过不响
                        case .ignoreHoliday:
                            isRingingByDefault = isBaseMatch // 忽略假节日，原样决定
                        }
                    case .workday:
                        // 遇到补班工作日
                        switch rule.policy {
                        case .followHoliday:
                            isRingingByDefault = true // 补班强行响铃
                        case .skipHoliday, .ignoreHoliday:
                            isRingingByDefault = isBaseMatch // 补班不强行，按原星期规则
                        }
                    }
                } else {
                    // 普通日子，按基础星期决定
                    isRingingByDefault = isBaseMatch
                }
                
            case .alternatingWeeks(let rule):
                // 获取锚点周和当前周的周度起始日期，计算它们相差的周数
                let startOfAnchorWeek = calendar.dateInterval(of: .weekOfYear, for: rule.anchorDate)?.start ?? rule.anchorDate
                let startOfCurrentWeek = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
                let weeksDiff = calendar.dateComponents([.weekOfYear], from: startOfAnchorWeek, to: startOfCurrentWeek).weekOfYear ?? 0
                
                let currentWeekType: WeekType
                if abs(weeksDiff) % 2 == 0 {
                    currentWeekType = rule.anchorWeekType
                } else {
                    currentWeekType = (rule.anchorWeekType == .weekA) ? .weekB : .weekA
                }
                
                let weekday = calendar.component(.weekday, from: currentDate)
                switch currentWeekType {
                case .weekA:
                    isRingingByDefault = rule.weekAWorkdays.contains(weekday)
                case .weekB:
                    isRingingByDefault = rule.weekBWorkdays.contains(weekday)
                }
                
            case .cycle(let rule):
                let startOfAnchor = calendar.startOfDay(for: rule.anchorDate)
                let startOfCurrent = calendar.startOfDay(for: currentDate)
                let daysDiff = calendar.dateComponents([.day], from: startOfAnchor, to: startOfCurrent).day ?? 0
                
                let count = rule.cycleDays.count
                if count > 0 {
                    // 双向求模，确保比锚点早的日期也能正确推算
                    let index = ((daysDiff % count) + count) % count
                    let cycleDay = rule.cycleDays[index]
                    isRingingByDefault = cycleDay.isRinging
                    if isRingingByDefault, let timeOverride = cycleDay.timeOverride {
                        defaultRingTime = timeOverride
                    }
                }
            }
            
            // 3.5 根据全局默认节假日策略，对长期重复规则在法定假期/补班日进行智能过滤和追加
            let isRepeatingRule: Bool = {
                switch schedule.rule {
                case .once:
                    return false
                case .chineseWorkday:
                    // chineseWorkday 内部已经自带了政策处理，这里不需要二次处理
                    return false
                default:
                    return true
                }
            }()
            
            if isRepeatingRule {
                let globalPolicyRaw = UserDefaults.standard.string(forKey: "defaultHolidayPolicy") ?? ChineseWorkdayPolicy.skipHoliday.rawValue
                let globalPolicy = holidayPolicy ?? ChineseWorkdayPolicy(rawValue: globalPolicyRaw) ?? .skipHoliday
                
                if let holidayType = holidays.checkHoliday(on: currentDate) {
                    switch holidayType {
                    case .holiday:
                        if globalPolicy == .followHoliday || globalPolicy == .skipHoliday {
                            isRingingByDefault = false // 法定假期，智能跳过不响
                        }
                    case .workday:
                        if globalPolicy == .followHoliday {
                            isRingingByDefault = true // 调休补班，智能强行响铃
                        }
                    }
                }
            }
            
            // 4. 应用 Override 覆盖决策
            var isRinging = isRingingByDefault
            var ringTime = defaultRingTime
            
            if let override = dayOverride {
                switch override.action {
                case .skip:
                    isRinging = false
                case .forceWorking:
                    isRinging = true
                    ringTime = schedule.time
                case .changeTime(let newTime):
                    isRinging = true
                    ringTime = newTime
                }
            }
            
            if let start = schedule.vacationStart, let end = schedule.vacationEnd,
               currentDate >= calendar.startOfDay(for: start),
               currentDate <= calendar.startOfDay(for: end) {
                isRinging = false
            }

            // 5. 若响铃，生成实例并加入结果集
            if isRinging {
                var fireComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                fireComponents.hour = ringTime.hour
                fireComponents.minute = ringTime.minute
                fireComponents.second = 0
                
                if let fireDate = calendar.date(from: fireComponents) {
                    // 生成的闹铃具体时刻必须在查询的时间闭区间内
                    if fireDate >= dateRange.lowerBound && fireDate <= dateRange.upperBound {
                        let stableID = AlarmOccurrence.generateStableID(scheduleID: schedule.id, fireDate: fireDate)
                        let occurrence = AlarmOccurrence(
                            id: stableID,
                            scheduleID: schedule.id,
                            fireDate: fireDate,
                            label: schedule.name,
                            sound: schedule.sound,
                            snooze: schedule.snooze
                        )
                        occurrences.append(occurrence)
                    }
                }
            }
            
            // 递增到下一天
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return occurrences
    }
}
