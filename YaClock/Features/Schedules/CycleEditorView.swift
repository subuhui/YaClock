// @Author subuhui
// @Date 2026/7/12 20:13
// @Description 自定义轮班周期（班制）编辑器，支持首个唤醒时间、锚定日期、班次卡片增删改及拖放排序

import SwiftUI
import UniformTypeIdentifiers

/// 轮班制设置编辑 Sheet 页面
struct CycleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 父级绑定数据
    @Binding var defaultHour: Int
    @Binding var defaultMinute: Int
    @Binding var anchorDate: Date
    @Binding var cycleDays: [CycleDay]
    
    // MARK: - 局部临时状态
    @State private var tempHour: Int
    @State private var tempMinute: Int
    @State private var tempAnchorDate: Date
    @State private var tempCycleDays: [EditableCycleDay]
    
    // MARK: - 弹窗控制状态
    @State private var showingTimePicker = false
    @State private var showingDatePicker = false
    @State private var editingDay: EditableCycleDay?
    
    // 用于拖拽排序的临时变量
    @State private var draggedDay: EditableCycleDay?
    
    init(defaultHour: Binding<Int>, defaultMinute: Binding<Int>, anchorDate: Binding<Date>, cycleDays: Binding<[CycleDay]>) {
        self._defaultHour = defaultHour
        self._defaultMinute = defaultMinute
        self._anchorDate = anchorDate
        self._cycleDays = cycleDays
        
        self._tempHour = State(initialValue: defaultHour.wrappedValue)
        self._tempMinute = State(initialValue: defaultMinute.wrappedValue)
        self._tempAnchorDate = State(initialValue: anchorDate.wrappedValue)
        
        // 将 Domain 层模型 [CycleDay] 包装为带 UUID 的 [EditableCycleDay]，保证 Identifiable 可唯一标识和排序
        let wrapped = cycleDays.wrappedValue.map { EditableCycleDay(from: $0) }
        self._tempCycleDays = State(initialValue: wrapped)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - 1. 首个唤醒时间卡片
                    VStack(spacing: 12) {
                        Text("首个唤醒时间")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // 大字号时间显示
                        Button {
                            showingTimePicker = true
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(displayHour)
                                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                
                                Text(displayMinute)
                                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                
                                Text(periodString)
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // 循环天数动态气泡
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                            Text("\(tempCycleDays.count) 天一循环")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemFill))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    
                    // MARK: - 2. 锚定起始日期卡片
                    VStack(alignment: .leading, spacing: 8) {
                        Text("锚定起始日期")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        
                        Button {
                            showingDatePicker = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundStyle(Color(hex: "344557"))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formattedAnchorDate)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("循环将从此日期开始计算")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - 3. 循环周期排班列表
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("循环周期排班")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("长按手柄拖动排序")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            ForEach(tempCycleDays) { day in
                                let index = tempCycleDays.firstIndex(of: day) ?? 0
                                
                                EditableCycleDayCard(
                                    day: day,
                                    index: index,
                                    defaultHour: tempHour,
                                    defaultMinute: tempMinute,
                                    onEdit: {
                                        editingDay = day
                                    }
                                )
                                .onDrag {
                                    self.draggedDay = day
                                    // 必须设置拖拽数据以触发 Drag & Drop 流程
                                    return NSItemProvider(object: day.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: CycleDropDelegate(item: day, listData: $tempCycleDays, draggedItem: $draggedDay))
                            }
                            
                            // ＋ 添加循环天数虚线卡片
                            Button {
                                addCycleDay()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                        .font(.body)
                                    Text("添加循环天数")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                                        .foregroundStyle(.tertiary)
                                )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                    }
                    
                    // MARK: - 4. 智能提示区域
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        
                        Text(smartTipText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                        
                        Spacer()
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 4)
                    
                    // MARK: - 5. 底部取消与保存设置按钮
                    HStack(spacing: 16) {
                        Button {
                            dismiss()
                        } label: {
                            Text("取消")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(.systemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        
                        Button {
                            saveSettings()
                        } label: {
                            Text("保存设置")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(hex: "344557"))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("轮班制设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 问号帮助按钮，这里可以展示一些轮班说明
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
            // MARK: - Bottom Sheet 弹窗挂载
            // 1. 首个唤醒时间选择器
            .sheet(isPresented: $showingTimePicker) {
                timePickerSheet
            }
            // 2. 锚定起始日期选择器
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            // 3. 班次详细编辑 Sheet
            .sheet(item: $editingDay) { day in
                dayEditorSheet(for: day)
            }
        }
    }
    
    // MARK: - 首个唤醒时间大字号格式化辅助
    private var displayHour: String {
        let h = tempHour % 12
        let displayH = h == 0 ? 12 : h
        return String(format: "%02d:", displayH)
    }
    
    private var displayMinute: String {
        return String(format: "%02d", tempMinute)
    }
    
    private var periodString: String {
        tempHour >= 12 ? "PM" : "AM"
    }
    
    private var formattedAnchorDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: tempAnchorDate)
    }
    
    // MARK: - 智能提示文案计算
    private var smartTipText: String {
        let count = tempCycleDays.count
        guard count > 0 else {
            return "请添加班次以配置轮班周期。"
        }
        
        let calendar = Calendar.current
        let today = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return ""
        }
        
        let startOfAnchor = calendar.startOfDay(for: tempAnchorDate)
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        let daysDiff = calendar.dateComponents([.day], from: startOfAnchor, to: startOfTomorrow).day ?? 0
        
        let index = ((daysDiff % count) + count) % count
        let tomorrowDayNum = index + 1
        let tomorrowDayName = tempCycleDays[index].name
        
        let anchorFormatter = DateFormatter()
        anchorFormatter.dateFormat = "yyyy年M月d日"
        let anchorString = anchorFormatter.string(from: tempAnchorDate)
        
        let tomorrowFormatter = DateFormatter()
        tomorrowFormatter.dateFormat = "M月d日"
        let tomorrowString = tomorrowFormatter.string(from: tomorrow)
        
        return "当前设置为 \(count)天一循环。基于 \(anchorString) 锚定，明天（\(tomorrowString)）将会自动识别为 第 \(tomorrowDayNum) 天（\(tomorrowDayName)）。"
    }
    
    // MARK: - 班次操作与保存逻辑
    private func addCycleDay() {
        let count = tempCycleDays.count
        let name: String
        let isWorking: Bool
        let isRinging: Bool
        
        // 智能推测：根据前一个班次建议
        if count == 0 {
            name = "白班"
            isWorking = true
            isRinging = true
        } else {
            let last = tempCycleDays[count - 1]
            if last.name == "白班" {
                name = "夜班"
                isWorking = true
                isRinging = true
            } else if last.name == "夜班" {
                name = "休息"
                isWorking = false
                isRinging = false
            } else {
                name = "白班"
                isWorking = true
                isRinging = true
            }
        }
        
        withAnimation {
            tempCycleDays.append(EditableCycleDay(name: name, isWorking: isWorking, isRinging: isRinging))
        }
    }
    
    private func saveSettings() {
        // 更新父绑定的原始状态
        defaultHour = tempHour
        defaultMinute = tempMinute
        anchorDate = tempAnchorDate
        cycleDays = tempCycleDays.map { $0.toDomain() }
        dismiss()
    }
    
    // MARK: - 弹窗内容 ViewBuilder
    
    // 1. 时间选择 Wheel Sheet
    private var timePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "响铃时间",
                    selection: Binding(
                        get: {
                            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                            c.hour = tempHour
                            c.minute = tempMinute
                            return Calendar.current.date(from: c) ?? Date()
                        },
                        set: { date in
                            tempHour = Calendar.current.component(.hour, from: date)
                            tempMinute = Calendar.current.component(.minute, from: date)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("选择首个唤醒时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showingTimePicker = false }
                }
            }
            .presentationDetents([.height(260)])
        }
    }
    
    // 2. 日期选择 Wheel/Graphical Sheet
    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "锚定起始日期",
                    selection: $tempAnchorDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("选择锚定起始日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showingDatePicker = false }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // 3. 周期日详细配置 Sheet
    private func dayEditorSheet(for day: EditableCycleDay) -> some View {
        // 创建一个单独的包裹视图来持有临时状态并实现绑定
        DayEditorSheetView(day: day) { updatedDay in
            if let index = tempCycleDays.firstIndex(where: { $0.id == day.id }) {
                tempCycleDays[index] = updatedDay
            }
            editingDay = nil
        } onDelete: {
            if let index = tempCycleDays.firstIndex(where: { $0.id == day.id }) {
                withAnimation {
                    tempCycleDays.remove(at: index)
                }
            }
            editingDay = nil
        }
    }
}

// MARK: - 辅助结构与组件

/// UI 排班列表项卡片
struct EditableCycleDayCard: View {
    let day: EditableCycleDay
    let index: Int
    let defaultHour: Int
    let defaultMinute: Int
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧六点/三线拖拽手柄
            Image(systemName: "line.3.horizontal")
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 44)
            
            // 天数及班次名称
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(index + 1) 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(day.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // 响铃时间/状态标签
            HStack(spacing: 6) {
                if !day.isRinging {
                    Text("全天无闹钟")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    let time = day.timeOverride ?? LocalTime(hour: defaultHour, minute: defaultMinute)
                    
                    Text(String(format: "%02d:%02d", time.hour, time.minute))
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(backgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            
            // 右侧编辑按钮
            Button {
                onEdit()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "344557"))
                    .frame(width: 36, height: 36)
                    .background(Color(.systemFill).opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 3)
    }
    
    // 根据班次名称智能配色
    private var isNightShift: Bool {
        day.name.contains("夜") || day.name.contains("晚")
    }
    
    private var isOffShift: Bool {
        day.name.contains("休") || day.name.contains("息")
    }
    
    private var textColor: Color {
        if isNightShift {
            return Color(hex: "5E35B1") // 深紫色
        } else if isOffShift {
            return Color.gray
        } else {
            return Color(hex: "F57C00") // 深橙色
        }
    }
    
    private var backgroundColor: Color {
        if isNightShift {
            return Color(hex: "EDE7F6") // 浅紫色
        } else if isOffShift {
            return Color.gray.opacity(0.12)
        } else {
            return Color(hex: "FFF3E0") // 浅橙色
        }
    }
}

/// 班次编辑的子 Sheet 视图
struct DayEditorSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var isWorking: Bool
    @State private var isRinging: Bool
    @State private var useCustomTime: Bool
    @State private var overrideHour: Int
    @State private var overrideMinute: Int
    
    let originalDay: EditableCycleDay
    let onSave: (EditableCycleDay) -> Void
    let onDelete: () -> Void
    
    init(day: EditableCycleDay, onSave: @escaping (EditableCycleDay) -> Void, onDelete: @escaping () -> Void) {
        self.originalDay = day
        self.onSave = onSave
        self.onDelete = onDelete
        
        self._name = State(initialValue: day.name)
        self._isWorking = State(initialValue: day.isWorking)
        self._isRinging = State(initialValue: day.isRinging)
        self._useCustomTime = State(initialValue: day.timeOverride != nil)
        
        let t = day.timeOverride ?? LocalTime(hour: 8, minute: 0)
        self._overrideHour = State(initialValue: t.hour)
        self._overrideMinute = State(initialValue: t.minute)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本配置") {
                    HStack {
                        Text("班次名称")
                        Spacer()
                        TextField("例：白班", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Toggle("是否工作", isOn: $isWorking)
                    Toggle("是否响铃", isOn: $isRinging)
                }
                
                if isRinging {
                    Section("响铃时间") {
                        Toggle("自定义响铃时间", isOn: $useCustomTime)
                        
                        if useCustomTime {
                            DatePicker(
                                "响铃时间",
                                selection: Binding(
                                    get: {
                                        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                        c.hour = overrideHour
                                        c.minute = overrideMinute
                                        return Calendar.current.date(from: c) ?? Date()
                                    },
                                    set: { date in
                                        overrideHour = Calendar.current.component(.hour, from: date)
                                        overrideMinute = Calendar.current.component(.minute, from: date)
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Text("使用规则默认时间")
                                Spacer()
                                Text("默认响铃时间")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Spacer()
                            Label("删除此天", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("编辑班次配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        let finalTime = useCustomTime ? LocalTime(hour: overrideHour, minute: overrideMinute) : nil
                        let updated = EditableCycleDay(
                            id: originalDay.id,
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "新班次" : name,
                            isWorking: isWorking,
                            isRinging: isRinging,
                            timeOverride: finalTime
                        )
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - UI 包装体与拖放代理实现

/// 轮班周期中专用于 UI 编辑的包装类，包含 UUID 以实现 Identifiable 与 Equatable
struct EditableCycleDay: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isWorking: Bool
    var isRinging: Bool
    var timeOverride: LocalTime?
    
    init(id: UUID = UUID(), name: String, isWorking: Bool, isRinging: Bool, timeOverride: LocalTime? = nil) {
        self.id = id
        self.name = name
        self.isWorking = isWorking
        self.isRinging = isRinging
        self.timeOverride = timeOverride
    }
    
    init(from domain: CycleDay) {
        self.id = UUID()
        self.name = domain.name
        self.isWorking = domain.isWorking
        self.isRinging = domain.isRinging
        self.timeOverride = domain.timeOverride
    }
    
    func toDomain() -> CycleDay {
        return CycleDay(name: name, isWorking: isWorking, isRinging: isRinging, timeOverride: timeOverride)
    }
}

/// 轮班列表拖拽重新排序代理
struct CycleDropDelegate: DropDelegate {
    let item: EditableCycleDay
    @Binding var listData: [EditableCycleDay]
    @Binding var draggedItem: EditableCycleDay?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem, draggedItem != item else { return }
        
        let from = listData.firstIndex(of: draggedItem)
        let to = listData.firstIndex(of: item)
        
        if let from = from, let to = to {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                listData.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
}
