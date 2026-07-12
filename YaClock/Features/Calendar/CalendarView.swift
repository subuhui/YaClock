// @Author subuhui
// @Date 2026/7/12 11:28
// @Description 日历 Tab 视图，展示月份日历、节假日标注、响铃圆点以及选中日期的详情 Sheet

import SwiftUI

struct CalendarView: View {
    @State private var viewModel: CalendarViewModel
    @Environment(AppContainer.self) private var container

    @State private var showingDayDetail = false

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
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
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

    // MARK: - 单日格子

    private func dayCell(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNum = calendar.component(.day, from: date)
        let dateKey = dayKey(date)
        let hasRinging = viewModel.ringingDays.contains(dateKey)
        let holidayType = HolidayProvider().checkHoliday(on: date)
        let isWeekend = {
            let w = calendar.component(.weekday, from: date)
            return w == 1 || w == 7
        }()

        return Button {
            viewModel.selectDate(date)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 32, height: 32)
                    } else if isToday {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }

                    VStack(spacing: 0) {
                        Text("\(dayNum)")
                            .font(.system(size: 15, weight: isToday || isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : isWeekend ? .red.opacity(0.8) : .primary)

                        if holidayType != nil {
                            Text(holidayBadge(holidayType!))
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .red.opacity(0.7))
                        }
                    }
                }

                // 响铃圆点
                Circle()
                    .fill(hasRinging ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 44)
    }

    // MARK: - 选中日详情

    @ViewBuilder
    private var dayDetailSection: some View {
        let formatter = DateFormatter()
        let _ = { formatter.dateFormat = "M月d日" }()

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .clipShape(Capsule())
                Text("\(formatter.string(from: viewModel.selectedDate)) 详情")
                    .font(.headline)
            }
            .frame(height: 20)

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

    private func holidayBadge(_ type: HolidayType) -> String {
        switch type {
        case .holiday: return "休"
        case .workday: return "班"
        }
    }
}
