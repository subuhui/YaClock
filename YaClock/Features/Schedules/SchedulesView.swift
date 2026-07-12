// @Author subuhui
// @Date 2026/7/12 12:00
// @Description 作息 Tab 的主页面，展示即将响铃卡片和全部作息列表，使用 SchedulesViewModel 管理状态

import SwiftUI

struct SchedulesView: View {
    @State private var viewModel: SchedulesViewModel
    @State private var showingEditor = false
    @State private var editingSchedule: Schedule?

    init(container: AppContainer) {
        _viewModel = State(wrappedValue: SchedulesViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if viewModel.schedules.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 即将到来 Banner
                            upcomingBanner
                                .padding(.horizontal)

                            // 全部作息
                            allSchedulesSection
                                .padding(.horizontal)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("作息")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingSchedule = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor, onDismiss: { viewModel.onAppear() }) {
                ScheduleEditorView(schedule: editingSchedule)
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - 即将到来 Banner

    @ViewBuilder
    private var upcomingBanner: some View {
        if let occ = viewModel.nextOccurrence {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("即将到来")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(timeString(from: occ.fireDate))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text(occ.label)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(countdownDescription(for: occ.fireDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "alarm")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - 全部作息

    private var allSchedulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("所有作息")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(viewModel.schedules) { schedule in
                    scheduleCard(schedule)
                }
            }
        }
    }

    private func scheduleCard(_ schedule: Schedule) -> some View {
        Button {
            editingSchedule = schedule
            showingEditor = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(schedule.time.hour, specifier: "%02d"):\(schedule.time.minute, specifier: "%02d")")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(schedule.isEnabled ? .primary : .secondary)

                        Text(ruleShortDescription(schedule.rule))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(18)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.delete(id: schedule.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "alarm.slash")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            Text("定义你的节奏，管理你的时间")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button("新建作息") {
                showingEditor = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - 辅助方法

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func countdownDescription(for date: Date) -> String {
        let diff = date.timeIntervalSince(Date())
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        return "将在 \(h) 小时 \(m) 分钟后响起"
    }

    private func ruleShortDescription(_ rule: ScheduleRule) -> String {
        switch rule {
        case .once:              return "单次"
        case .weekly(let r):     return weeklyShort(r.repeatDays)
        case .chineseWorkday:    return "工作日"
        case .alternatingWeeks:  return "大小周"
        case .cycle(let r):      return "每\(r.cycleDays.count)天一次"
        }
    }

    private func weeklyShort(_ days: [Int]) -> String {
        let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let sorted = days.sorted()
        if sorted == [2, 3, 4, 5, 6] { return "周一至周五" }
        if sorted == [1, 7] { return "周末" }
        return sorted.compactMap { (0..<names.count).contains($0) ? names[$0] : nil }.joined(separator: "、")
    }
}

