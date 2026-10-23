// @Author subuhui
// @Date 2026/7/12 11:57
// @Description 日历单日控制中心 Bottom Sheet，支持跳过当天、临时强制响铃、修改时间、恢复默认四种 Override 操作

import SwiftUI

/// 日历单日控制中心，作为 .sheet 弹出展示
struct DayDetailSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    /// 选中日期
    let date: Date

    /// 该天生效的响铃实例（nil = 无计划）
    let occurrence: AlarmOccurrence?

    /// 该天的节假日状态
    let holidayType: HolidayType?

    /// 操作完成回调，通知父视图刷新数据
    var onChanged: () -> Void = {}

    @State private var showingChangeTimePicker = false
    @State private var pickerHour: Int = 7
    @State private var pickerMinute: Int = 0
    @State private var showingRestoreAlert = false
    @State private var isActing = false
    @State private var hasOverrides = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 日期标题行
                headerSection

                Divider()

                ScrollView {
                    VStack(spacing: 16) {
                        // 当天响铃状态卡片
                        statusCard
                            .padding(.horizontal)
                            .padding(.top, 16)

                        // 操作按钮组
                        actionButtons
                            .padding(.horizontal)

                        Spacer(minLength: 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            // 修改时间 Sheet
            .sheet(isPresented: $showingChangeTimePicker) {
                changeTimeSheet
            }
            // 恢复默认确认弹窗
            .confirmationDialog("恢复为默认规则", isPresented: $showingRestoreAlert, titleVisibility: .visible) {
                Button("恢复默认", role: .destructive) { performRestore() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当天的临时调整将被清除，将恢复到作息规则的默认状态。")
            }
        }
        .task {
            do {
                for schedule in try container.scheduleRepo.fetchAll() {
                    if try container.overrideRepo.fetchAll(for: schedule.id).contains(where: { Calendar.current.isDate($0.targetDate, inSameDayAs: date) }) { hasOverrides = true }
                }
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 顶部标题

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayTitle)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let holiday = holidayType {
                    Text(holidayLabel(holiday))
                        .font(.caption)
                        .foregroundStyle(holiday.isHoliday ? .red : .blue)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }

    // MARK: - 响铃状态卡片

    @ViewBuilder
    private var statusCard: some View {
        if let occ = occurrence {
            VStack(alignment: .leading, spacing: 10) {
                Label("计划起床时间", systemImage: "alarm")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(timeString(from: occ.fireDate))
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(occ.label)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }

                if let holiday = holidayType {
                    holidayInfoBanner(holiday)
                }
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.tertiary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今天没有计划闹钟")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("可以使用临时强制响铃为当天添加一次响铃")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - 操作按钮组

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 跳过当天（仅当有计划时显示）
            if occurrence != nil {
                actionButton(
                    title: "跳过当天",
                    subtitle: "今天不响铃，其他天不受影响",
                    icon: "nosign",
                    tint: .secondary
                ) {
                    performSkip()
                }
            }

            // 修改时间（仅当有计划时显示）
            if let occ = occurrence {
                actionButton(
                    title: "修改响铃时间",
                    subtitle: "仅影响当天",
                    icon: "pencil",
                    tint: .accentColor
                ) {
                    pickerHour = Calendar.current.component(.hour, from: occ.fireDate)
                    pickerMinute = Calendar.current.component(.minute, from: occ.fireDate)
                    showingChangeTimePicker = true
                }
            }

            // 临时强制响铃（当没有计划时显示，即 forceWorking）
            if occurrence == nil {
                actionButton(
                    title: "临时强制响铃",
                    subtitle: "按作息默认时间为今天添加一次闹钟",
                    icon: "alarm.fill",
                    tint: .orange
                ) {
                    performForceWorking()
                }
            }

            // 跳过后即使没有闹钟，也必须能撤销临时调整。
            if hasOverrides || occurrence != nil {
                actionButton(
                    title: "恢复默认规则",
                    subtitle: "清除所有临时调整",
                    icon: "arrow.counterclockwise",
                    tint: .red
                ) {
                    showingRestoreAlert = true
                }
            }
        }
    }

    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isActing)
    }

    // MARK: - 修改时间 Sheet

    private var changeTimeSheet: some View {
        NavigationStack {
            DatePicker(
                "选择响铃时间",
                selection: Binding(
                    get: {
                        var c = DateComponents()
                        c.hour = pickerHour
                        c.minute = pickerMinute
                        return Calendar.current.date(from: c) ?? Date()
                    },
                    set: { d in
                        pickerHour = Calendar.current.component(.hour, from: d)
                        pickerMinute = Calendar.current.component(.minute, from: d)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .navigationTitle("修改时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showingChangeTimePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        performChangeTime(hour: pickerHour, minute: pickerMinute)
                        showingChangeTimePicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    // MARK: - Override 操作执行

    private func performSkip() {
        guard let occ = occurrence else { return }
        isActing = true
        let override = ScheduleOverride(
            scheduleID: occ.scheduleID,
            targetDate: date,
            action: .skip
        )
        Task {
            try await container.saveOverrideUseCase.execute(override)
            isActing = false
            onChanged()
            dismiss()
        }
    }

    private func performForceWorking() {
        // forceWorking 需要关联一个作息 ID，此处从所有启用的作息中取第一个
        let schedules = (try? container.scheduleRepo.fetchAll())?.filter { $0.isEnabled } ?? []
        guard let first = schedules.first else { return }
        isActing = true
        let override = ScheduleOverride(
            scheduleID: first.id,
            targetDate: date,
            action: .forceWorking
        )
        Task {
            try await container.saveOverrideUseCase.execute(override)
            isActing = false
            onChanged()
            dismiss()
        }
    }

    private func performChangeTime(hour: Int, minute: Int) {
        guard let occ = occurrence else { return }
        isActing = true
        let override = ScheduleOverride(
            scheduleID: occ.scheduleID,
            targetDate: date,
            action: .changeTime(LocalTime(hour: hour, minute: minute))
        )
        Task {
            try await container.saveOverrideUseCase.execute(override)
            isActing = false
            onChanged()
        }
    }

    private func performRestore() {
        isActing = true
        Task {
            do {
                try await container.deleteOverrideUseCase.execute(on: date)
                onChanged()
                dismiss()
            } catch { errorMessage = error.localizedDescription }
            isActing = false
        }
    }

    // MARK: - 节假日 Banner

    private func holidayInfoBanner(_ type: HolidayType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(holidayHint(type))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 辅助

    private var dayTitle: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: date)
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func holidayLabel(_ type: HolidayType) -> String {
        switch type {
        case .holiday(let name): return "法定假期 · \(name)"
        case .workday(let reason): return "调休补班 · \(reason)"
        }
    }

    private func holidayHint(_ type: HolidayType) -> String {
        switch type {
        case .holiday(let name): return "今天是\(name)，响铃策略已按规则自动调整"
        case .workday(let reason): return "今天是\(reason)，按工作日规则响铃"
        }
    }
}

// MARK: - HolidayType 辅助

private extension HolidayType {
    var isHoliday: Bool {
        if case .holiday = self { return true }
        return false
    }
}
