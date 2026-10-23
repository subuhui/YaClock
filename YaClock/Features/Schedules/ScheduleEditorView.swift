// @Author subuhui
// @Date 2026/7/12 11:28
// @Description 作息新建/编辑 Sheet，支持时间选择、规则选择（周重复/节假日/大小周/轮班）和铃声配置

import SwiftUI

struct ScheduleEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    // MARK: - 编辑状态

    /// 非 nil 表示编辑模式，nil 为新建
    let originalSchedule: Schedule?
    let isNew: Bool
    @State private var errorMessage: String?
    @State private var scheduleID: UUID

    @State private var name: String
    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @State private var ruleType: RuleTypeOption
    @State private var repeatDays: Set<Int>     // 用于 weekly / chineseWorkday
    @State private var holidayPolicy: ChineseWorkdayPolicy
    @State private var anchorDate: Date          // alternatingWeeks / cycle
    @State private var anchorWeekType: WeekType
    @State private var weekADays: Set<Int>
    @State private var weekBDays: Set<Int>
    @State private var cycleDays: [CycleDay]
    @State private var snoozeEnabled: Bool
    @State private var snoozeDuration: Int
    @State private var isSaving = false
    @State private var showingCycleEditor = false

    init(schedule: Schedule?, isNew: Bool = false) {
        self.isNew = isNew || schedule == nil
        self.originalSchedule = schedule
        self._scheduleID = State(wrappedValue: schedule?.id ?? UUID())

        var name = ""
        var selectedHour = 7
        var selectedMinute = 30
        var ruleType = RuleTypeOption.weekly
        var repeatDays: Set<Int> = [2, 3, 4, 5, 6]
        var holidayPolicy = ChineseWorkdayPolicy.followHoliday
        var anchorDate = Date()
        var anchorWeekType = WeekType.weekA
        var weekADays: Set<Int> = [2, 3, 4, 5, 6]
        var weekBDays: Set<Int> = [2, 3, 4, 5, 6]
        var cycleDays: [CycleDay] = []
        var snoozeEnabled = true
        var snoozeDuration = 9

        if let s = schedule {
            name = s.name
            selectedHour = s.time.hour
            selectedMinute = s.time.minute
            snoozeEnabled = s.snooze.isEnabled
            snoozeDuration = s.snooze.durationMinutes

            switch s.rule {
            case .weekly(let r):
                ruleType = .weekly
                repeatDays = Set(r.repeatDays)
            case .chineseWorkday(let r):
                ruleType = .chineseWorkday
                repeatDays = Set(r.repeatDays)
                holidayPolicy = r.policy
            case .alternatingWeeks(let r):
                ruleType = .alternatingWeeks
                anchorDate = r.anchorDate
                anchorWeekType = r.anchorWeekType
                weekADays = Set(r.weekAWorkdays)
                weekBDays = Set(r.weekBWorkdays)
                repeatDays = []
            case .cycle(let r):
                ruleType = .cycle
                anchorDate = r.anchorDate
                cycleDays = r.cycleDays
                repeatDays = []
            case .once(let r):
                ruleType = .weekly
                repeatDays = [Calendar.current.component(.weekday, from: r.date)]
            }
        }

        self._name = State(wrappedValue: name)
        self._selectedHour = State(wrappedValue: selectedHour)
        self._selectedMinute = State(wrappedValue: selectedMinute)
        self._ruleType = State(wrappedValue: ruleType)
        self._repeatDays = State(wrappedValue: repeatDays)
        self._holidayPolicy = State(wrappedValue: holidayPolicy)
        self._anchorDate = State(wrappedValue: anchorDate)
        self._anchorWeekType = State(wrappedValue: anchorWeekType)
        self._weekADays = State(wrappedValue: weekADays)
        self._weekBDays = State(wrappedValue: weekBDays)
        self._cycleDays = State(wrappedValue: cycleDays)
        self._snoozeEnabled = State(wrappedValue: snoozeEnabled)
        self._snoozeDuration = State(wrappedValue: snoozeDuration)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 时间选择
                Section {
                    DatePicker(
                        "响铃时间",
                        selection: Binding(
                            get: {
                                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                c.hour = selectedHour
                                c.minute = selectedMinute
                                return Calendar.current.date(from: c) ?? Date()
                            },
                            set: { date in
                                selectedHour = Calendar.current.component(.hour, from: date)
                                selectedMinute = Calendar.current.component(.minute, from: date)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    Text("起床时间")
                }

                // MARK: 名称
                Section {
                    TextField("例：常规工作日", text: $name)
                } header: {
                    Text("名称")
                }

                // MARK: 重复规则
                Section {
                    Picker("规则类型", selection: $ruleType) {
                        ForEach(RuleTypeOption.allCases) { opt in
                            Text(opt.displayName).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)

                    // 根据规则类型展示不同子控件
                    switch ruleType {
                    case .weekly:
                        weekdayPicker(title: "重复星期", selection: $repeatDays)

                    case .chineseWorkday:
                        weekdayPicker(title: "基础星期", selection: $repeatDays)
                        Picker("节假日政策", selection: $holidayPolicy) {
                            Text("随调休（推荐）").tag(ChineseWorkdayPolicy.followHoliday)
                            Text("只跳假期").tag(ChineseWorkdayPolicy.skipHoliday)
                            Text("忽略假期").tag(ChineseWorkdayPolicy.ignoreHoliday)
                        }
                        .pickerStyle(.menu)

                    case .alternatingWeeks:
                        DatePicker("锚点日期", selection: $anchorDate, displayedComponents: .date)
                        Picker("锚点周类型", selection: $anchorWeekType) {
                            Text("A 周（大周）").tag(WeekType.weekA)
                            Text("B 周（小周）").tag(WeekType.weekB)
                        }
                        .pickerStyle(.segmented)
                        weekdayPicker(title: "A 周响铃", selection: $weekADays)
                        weekdayPicker(title: "B 周响铃", selection: $weekBDays)

                    case .cycle:
                        Button {
                            showingCycleEditor = true
                        } label: {
                            HStack {
                                Text("设置轮班周期")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if cycleDays.isEmpty {
                                    Text("未设置")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(cycleDays.count)天一循环")
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                } header: {
                    Text("重复规则")
                }

                // MARK: 贪睡
                Section {
                    Toggle("开启贪睡", isOn: $snoozeEnabled)
                    if snoozeEnabled {
                        Stepper("贪睡 \(snoozeDuration) 分钟", value: $snoozeDuration, in: 1...30)
                    }
                } header: {
                    Text("贪睡")
                }

                // MARK: 删除（仅编辑模式）
                if originalSchedule != nil && !isNew {
                    Section {
                        Button(role: .destructive) {
                            if let id = originalSchedule?.id {
                                Task {
                                    do {
                                        try await container.deleteScheduleUseCase.execute(id: id)
                                        dismiss()
                                    } catch { errorMessage = error.localizedDescription }
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("删除作息", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .alert("无法完成操作", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .navigationTitle(isNew ? "新建作息" : "编辑作息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .sheet(isPresented: $showingCycleEditor) {
                CycleEditorView(
                    defaultHour: $selectedHour,
                    defaultMinute: $selectedMinute,
                    anchorDate: $anchorDate,
                    cycleDays: $cycleDays
                )
            }
        }
    }

    // MARK: - 星期多选组件

    private func weekdayPicker(title: String, selection: Binding<Set<Int>>) -> some View {
        let labels = ["", "日", "一", "二", "三", "四", "五", "六"]
        return HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    let selected = selection.wrappedValue.contains(day)
                    Button {
                        if selected {
                            selection.wrappedValue.remove(day)
                        } else {
                            selection.wrappedValue.insert(day)
                        }
                    } label: {
                        Text(labels[day])
                            .font(.caption)
                            .frame(width: 28, height: 28)
                            .background(selected ? Color.accentColor : Color(.systemFill))
                            .foregroundStyle(selected ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    // MARK: - 保存

    func makeSchedule() -> Schedule {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let rule = buildRule()
        return Schedule(
            id: scheduleID,
            name: trimmedName.isEmpty ? "未命名作息" : trimmedName,
            time: LocalTime(hour: selectedHour, minute: selectedMinute),
            rule: rule,
            sound: originalSchedule?.sound ?? AlarmSound(name: "default", type: .system),
            snooze: SnoozeConfiguration(isEnabled: snoozeEnabled, durationMinutes: snoozeDuration),
            isEnabled: originalSchedule?.isEnabled ?? true,
            startDate: originalSchedule?.startDate ?? Date(),
            endDate: originalSchedule?.endDate,
            vacationStart: isNew ? nil : originalSchedule?.vacationStart,
            vacationEnd: isNew ? nil : originalSchedule?.vacationEnd
        )
    }

    private func save() {
        let schedule = makeSchedule()
        isSaving = true
        Task {
            do {
                try await container.saveScheduleUseCase.execute(schedule)
                dismiss()
            } catch { errorMessage = "作息已保存在本机，但同步失败：\(error.localizedDescription)。请重试。" }
            isSaving = false
        }
    }

    private func buildRule() -> ScheduleRule {
        switch ruleType {
        case .weekly:
            return .weekly(WeeklyRule(repeatDays: Array(repeatDays)))
        case .chineseWorkday:
            return .chineseWorkday(ChineseWorkdayRule(policy: holidayPolicy, repeatDays: Array(repeatDays)))
        case .alternatingWeeks:
            return .alternatingWeeks(AlternatingWeeksRule(
                anchorDate: anchorDate,
                anchorWeekType: anchorWeekType,
                weekAWorkdays: Array(weekADays),
                weekBWorkdays: Array(weekBDays)
            ))
        case .cycle:
            return .cycle(CycleRule(anchorDate: anchorDate, cycleDays: cycleDays))
        }
    }
}

// MARK: - 规则类型枚举

enum RuleTypeOption: String, CaseIterable, Identifiable {
    case weekly          = "weekly"
    case chineseWorkday  = "chineseWorkday"
    case alternatingWeeks = "alternatingWeeks"
    case cycle           = "cycle"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly:           return "每周重复"
        case .chineseWorkday:   return "工作日（节假日调休）"
        case .alternatingWeeks: return "大小周"
        case .cycle:            return "自定义轮班周期"
        }
    }
}

// MARK: - ScheduleRule 辅助扩展

private extension ScheduleRule {
    var isAlternatingWeeks: Bool {
        if case .alternatingWeeks = self { return true }
        return false
    }
    var isCycle: Bool {
        if case .cycle = self { return true }
        return false
    }
}
