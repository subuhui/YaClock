// @Author subuhui
// @Date 2026/7/12 11:28
// @Description Today 首页视图，展示下一次起床时间 Hero 卡片、今日日程状态以及常用计划快捷切换

import SwiftUI

struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @State private var showingSettings = false
    @Environment(AppContainer.self) private var container

    init(container: AppContainer) {
        _viewModel = State(wrappedValue: TodayViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Hero 卡片：下一次闹钟
                        nextAlarmCard
                            .padding(.horizontal)

                        // 今日日程状态
                        todayStatusCard
                            .padding(.horizontal)

                        // 常用计划快捷开关
                        schedulesSection
                            .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(greetingText)
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
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - 问候语

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "夜深了" }
        if hour < 12 { return "早上好" }
        if hour < 18 { return "下午好" }
        return "晚上好"
    }

    // MARK: - Hero 闹钟卡片

    @ViewBuilder
    private var nextAlarmCard: some View {
        if let next = viewModel.nextOccurrence {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("下一个闹钟")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "alarm")
                        .foregroundStyle(.secondary)
                }

                Text(next.label)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // 大时间数字
                Text(timeString(from: next.fireDate))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(dayLabel(for: next.fireDate))
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())

                    Text(viewModel.countdownText.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces) ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            emptyAlarmCard
        }
    }

    private var emptyAlarmCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("暂无计划")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("在「作息」页新建你的第一个作息表")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 今日日程状态

    private var todayStatusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("今日日程")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(viewModel.todayStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 常用计划列表

    @ViewBuilder
    private var schedulesSection: some View {
        let displayed = Array(viewModel.schedules.prefix(3))
        if !displayed.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("常用计划")
                        .font(.headline)
                    Spacer()
                    NavigationLink("查看全部") {
                        SchedulesView(container: container)
                    }
                    .font(.subheadline)
                }

                VStack(spacing: 0) {
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { index, schedule in
                        scheduleRow(schedule)

                        if index < displayed.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func scheduleRow(_ schedule: Schedule) -> some View {
        HStack(spacing: 14) {
            Image(systemName: ruleIcon(for: schedule.rule))
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(ruleDescription(for: schedule.rule)) · \(schedule.time.hour, specifier: "%02d"):\(schedule.time.minute, specifier: "%02d")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in viewModel.toggle(id: schedule.id) }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 辅助方法

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func ruleIcon(for rule: ScheduleRule) -> String {
        switch rule {
        case .once:              return "1.circle"
        case .weekly:            return "arrow.2.circlepath"
        case .chineseWorkday:    return "building.2"
        case .alternatingWeeks:  return "rectangle.split.2x1"
        case .cycle:             return "clock.arrow.circlepath"
        }
    }

    private func ruleDescription(for rule: ScheduleRule) -> String {
        switch rule {
        case .once:                              return "单次"
        case .weekly(let r):                     return weeklyDescription(r.repeatDays)
        case .chineseWorkday:                    return "工作日"
        case .alternatingWeeks:                  return "大小周"
        case .cycle(let r):                      return "\(r.cycleDays.count)天一循环"
        }
    }

    private func weeklyDescription(_ days: [Int]) -> String {
        if days.sorted() == [2, 3, 4, 5, 6] { return "周一至周五" }
        if days.sorted() == [1, 7] { return "周末" }
        let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return days.sorted().compactMap { names[safe: $0] }.joined(separator: "、")
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
