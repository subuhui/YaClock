// @Author subuhui
// @Date 2026/7/12 11:28
// @Description 日历 Tab 视图，展示月份日历、节假日标注、响铃圆点以及选中日期的详情 Sheet

import SwiftUI

struct CalendarView: View {
    @State private var viewModel: CalendarViewModel
    @Environment(AppContainer.self) private var container

    @State private var showingDayDetail = false
    @State private var showingSettings = false

    init(container: AppContainer) {
        _viewModel = State(wrappedValue: CalendarViewModel(container: container))
    }

    // MARK: - 日历日期网格计算

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: viewModel.displayMonth) else { return [] }
        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        // 按一=2对齐（系统默认 weekday 1=周日），偏移量让第一列是周一
        let offset = (weekday + 5) % 7 // 周一=0, 周二=1,..., 周日=6

        var days = [Date?](repeating: nil, count: offset)
        var current = firstDay
        while let next = calendar.date(byAdding: .day, value: 1, to: current),
              calendar.isDate(current, equalTo: firstDay, toGranularity: .month) {
            days.append(current)
            current = next
        }
        // 补齐最后一行
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // 月历卡片
                    calendarCard
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 选中日详情
                    dayDetailSection
                        .padding(.horizontal)
                        .padding(.top, 16)

                    Spacer()
                }
            }
            .navigationTitle("日历")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingDayDetail, onDismiss: { viewModel.onAppear() }) {
                DayDetailSheet(
                    date: viewModel.selectedDate,
                    occurrence: viewModel.selectedDayOccurrence,
                    holidayType: viewModel.selectedDayHolidayType,
                    onChanged: { viewModel.onAppear() }
                )
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - 月历卡片

    private var calendarCard: some View {
        VStack(spacing: 12) {
            // 月份导航标题
            HStack {
                Text(monthTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button { viewModel.previousMonth() } label: {
                    Image(systemName: "chevron.left").fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                Button { viewModel.nextMonth() } label: {
                    Image(systemName: "chevron.right").fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
            }

            // 星期行
            HStack {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(label == "六" || label == "日" ? .red.opacity(0.7) : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 节假日与调休标识数据结构

    private struct DayHolidayMark {
        let text: String
        let color: Color
    }

    /// 获取特定日期所对应的班休字样及配色
    private func getHolidayMark(for date: Date, isSelected: Bool) -> DayHolidayMark {
        let calendar = Calendar.current
        let holidayType = HolidayProvider().checkHoliday(on: date)
        
        if isSelected {
            // 被选中态：文字均为反白高亮，通过透明度稍作区分
            if let holidayType {
                switch holidayType {
                case .holiday: return DayHolidayMark(text: "假", color: .white.opacity(0.95))
                case .workday: return DayHolidayMark(text: "班", color: .white.opacity(0.95))
                }
            } else {
                let w = calendar.component(.weekday, from: date)
                if w == 1 || w == 7 {
                    return DayHolidayMark(text: "休", color: .white.opacity(0.8))
                } else {
                    return DayHolidayMark(text: "班", color: .white.opacity(0.8))
                }
            }
        } else {
            // 普通未选中态：严格遵循 Neutral UI + User Accent 规范配色
            if let holidayType {
                switch holidayType {
                case .holiday:
                    // 法定节假日：明亮红字“假”
                    return DayHolidayMark(text: "假", color: Color(hex: "DC2626"))
                case .workday:
                    // 调休补班日：主题强调蓝/Accent字“班”
                    return DayHolidayMark(text: "班", color: container.accentColorManager.color)
                }
            } else {
                let w = calendar.component(.weekday, from: date)
                if w == 1 || w == 7 {
                    // 普通周末：小“休”
                    return DayHolidayMark(text: "休", color: .secondary.opacity(0.6))
                } else {
                    // 普通工作日：小灰字“班”
                    return DayHolidayMark(text: "班", color: .secondary.opacity(0.4))
                }
            }
        }
    }

    // MARK: - 单日格子

    private func dayCell(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNum = calendar.component(.day, from: date)
        let dateKey = dayKey(date)
        let hasRinging = viewModel.ringingDays.contains(dateKey)
        let isWeekend = {
            let w = calendar.component(.weekday, from: date)
            return w == 1 || w == 7
        }()
        
        let mark = getHolidayMark(for: date, isSelected: isSelected)
        let accentColor = container.accentColorManager.color

        return Button {
            viewModel.selectDate(date)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 34, height: 34)
                    } else if isToday {
                        Circle()
                            .stroke(accentColor, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }

                    VStack(spacing: 1) {
                        Text("\(dayNum)")
                            .font(.system(size: 17, weight: isToday || isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : isWeekend ? .red.opacity(0.8) : .primary)

                        Text(mark.text)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(mark.color)
                    }
                }

                // 响铃圆点 (使用当前全局 Accent)
                Circle()
                    .fill(hasRinging ? accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 46)
    }

    // MARK: - 选中日详情

    @ViewBuilder
    private var dayDetailSection: some View {
        let formatter = DateFormatter()
        let _ = { formatter.dateFormat = "M月d日" }()

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(container.accentColorManager.color)
                    .frame(width: 3)
                    .clipShape(Capsule())
                Text("\(formatter.string(from: viewModel.selectedDate)) 详情")
                    .font(.headline)
            }
            .frame(height: 20)

            // 节假日或补班信息展示横幅
            if let holiday = viewModel.selectedDayHolidayType {
                HStack(spacing: 8) {
                    Image(systemName: isHoliday(holiday) ? "calendar.badge.clock" : "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundStyle(isHoliday(holiday) ? Color(hex: "DC2626") : container.accentColorManager.color)
                    Text(holidayLabelText(holiday))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isHoliday(holiday) ? Color(hex: "DC2626") : .primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isHoliday(holiday) ? Color(hex: "DC2626").opacity(0.08) : container.accentColorManager.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showingDayDetail = true
            } label: {
                if let occ = viewModel.selectedDayOccurrence {
                    selectedDayCard(occ)
                } else {
                    noAlarmCard
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func selectedDayCard(_ occ: AlarmOccurrence) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("计划起床时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(timeString(from: occ.fireDate))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text(occ.label)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var noAlarmCard: some View {
        HStack {
            Image(systemName: "moon.zzz")
                .foregroundStyle(.tertiary)
            Text("这一天没有计划响铃")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 辅助

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: viewModel.displayMonth)
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func isHoliday(_ type: HolidayType) -> Bool {
        if case .holiday = type { return true }
        return false
    }

    private func holidayLabelText(_ type: HolidayType) -> String {
        switch type {
        case .holiday(let name): return "今天是\(name)假期"
        case .workday(let reason): return "今天是工作日（\(reason)）"
        }
    }
}
