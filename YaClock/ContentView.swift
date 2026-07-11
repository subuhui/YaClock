import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAlarm.hour) private var alarms: [LocalAlarm]
    
    @State private var viewModel: AlarmListViewModel?
    
    struct AlarmSheetItem: Identifiable {
        let id = UUID()
        let alarm: LocalAlarm?
    }
    
    @State private var activeSheetItem: AlarmSheetItem?
    
    var body: some View {
        Group {
            if let vm = viewModel {
                NavigationStack {
                    List {
                        // 1. Authorization status banner
                        if !vm.isAuthorized {
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("系统闹钟权限未启用")
                                            .font(.headline)
                                    }
                                    Text("iOS 26 允许非系统闹钟通过底层 AlarmKit 框架直接注册为系统级闹钟。请授权以获得无视静音和专注模式的唤醒保障。")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        Task {
                                            await vm.requestAuthorization()
                                        }
                                    }) {
                                        Text("允许访问系统闹钟")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // 2. Local alarms list
                        Section(header: Text("我的闹钟")) {
                            if alarms.isEmpty {
                                ContentUnavailableView("无闹钟", systemImage: "alarm", description: Text("点击右上角 + 按钮添加一个闹钟"))
                            } else {
                                ForEach(alarms) { alarm in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                                                .font(.system(.title, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                                            
                                            HStack(spacing: 6) {
                                                if !alarm.label.isEmpty {
                                                    Text(alarm.label)
                                                }
                                                Text(formatRepeatDays(alarm.repeatDays))
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: Binding(
                                            get: { alarm.isEnabled },
                                            set: { newValue in
                                                vm.toggleAlarm(alarm, isEnabled: newValue)
                                            }
                                        ))
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        activeSheetItem = AlarmSheetItem(alarm: alarm)
                                    }
                                }
                                .onDelete { offsets in
                                    vm.deleteAlarms(at: offsets, from: alarms)
                                }
                            }
                        }
                        
                        // 3. iOS 26 System Queue Monitor
                        SystemMonitorView(systemAlarms: vm.systemAlarms, isAuthorized: vm.isAuthorized)
                    }
                    .navigationTitle("YaClock")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: {
                                activeSheetItem = AlarmSheetItem(alarm: nil)
                            }) {
                                Label("添加闹钟", systemImage: "plus")
                            }
                        }
                    }
                    .sheet(item: $activeSheetItem) { item in
                        AlarmEditSheet(modelContext: modelContext, alarmToEdit: item.alarm)
                    }
                    .onAppear {
                        vm.checkAuthorization()
                    }
                }
            } else {
                ProgressView("正在初始化...")
                    .onAppear {
                        viewModel = AlarmListViewModel(modelContext: modelContext)
                        viewModel?.checkAuthorization()
                    }
            }
        }
    }
    
    private func formatRepeatDays(_ days: [Int]) -> String {
        if days.isEmpty { return "只响一次" }
        if days.count == 7 { return "每天" }
        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return days.sorted().map { weekdayNames[$0 - 1] }.joined(separator: " ")
    }
}
