// @Author subuhui
// @Date 2026/7/12 12:00
// @Description 作息 Tab 的主页面，展示即将响铃卡片和全部作息列表，使用 SchedulesViewModel 管理状态

import SwiftUI

struct SchedulesView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: SchedulesViewModel
    
    /// 当前展开的编辑或新建作息弹窗状态，作为单一可信源控制 Sheet 弹出并传递关联数据，避免多状态同步引发的首次点击不弹出 Bug
    @State private var activeSheet: ActiveSheet?

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
            .alert("操作失败", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("好") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
            .navigationTitle("作息")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("空白作息") { activeSheet = .create }
                        ForEach(ScheduleTemplate.allCases) { template in
                            Button(template.rawValue) { activeSheet = .seed(template.makeSchedule()) }
                        }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新建作息或选择模板")
                }
            }
            .sheet(item: $activeSheet, onDismiss: { viewModel.onAppear() }) { sheetType in
                switch sheetType {
                case .create:
                    ScheduleEditorView(schedule: nil)
                case .seed(let schedule):
                    ScheduleEditorView(schedule: schedule, isNew: true)
                case .edit(let schedule):
                    ScheduleEditorView(schedule: schedule)
                }
            }
        }
        .onAppear { viewModel.onAppear() }
        .onChange(of: container.refreshUseCase.lastSync) { _, _ in viewModel.onAppear() }
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
            activeSheet = .edit(schedule)
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
            .padding(.trailing, 40)
            .padding(18)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .contextMenu {
            Button("复制作息", systemImage: "doc.on.doc") { activeSheet = .seed(schedule.copyForCreation()) }
            Button("删除", systemImage: "trash", role: .destructive) { viewModel.delete(id: schedule.id) }
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("复制作息", systemImage: "doc.on.doc") { activeSheet = .seed(schedule.copyForCreation()) }
                Button("删除", systemImage: "trash", role: .destructive) { viewModel.delete(id: schedule.id) }
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
            }
            .accessibilityLabel("作息操作：" + schedule.name)
            .padding(4)
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
            Image(systemName: "bell.slash")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            Text("定义你的节奏，管理你的时间")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button("新建作息") {
                activeSheet = .create
            }
            .buttonStyle(.borderedProminent)
            ForEach(ScheduleTemplate.allCases) { template in
                Button("使用\(template.rawValue)模板") { activeSheet = .seed(template.makeSchedule()) }
                    .frame(minHeight: 44)
            }
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

// MARK: - 弹窗状态管理

/// 编辑器弹窗的活跃类型，区分新建与编辑模式，并符合 Identifiable 协议以供 sheet(item:) 绑定
private enum ActiveSheet: Identifiable {
    /// 新建模式
    case create
    case seed(Schedule)
    /// 编辑模式，携带待编辑的作息数据
    case edit(Schedule)

    /// 唯一标识符，使枚举符合 Identifiable 协议
    var id: String {
        switch self {
        case .create:
            return "create"
        case .seed(let s):
            return "seed-" + s.id.uuidString
        case .edit(let s):
            return s.id.uuidString
        }
    }
}

