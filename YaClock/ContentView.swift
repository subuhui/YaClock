import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAlarm.hour) private var alarms: [LocalAlarm]
    
    @StateObject private var alarmKitService = AlarmKitService.shared
    
    @State private var showingEditSheet = false
    @State private var alarmToEdit: LocalAlarm?
    
    var body: some View {
        NavigationStack {
            List {
                // 1. Authorization status banner
                if !alarmKitService.isAuthorized {
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
                                    _ = await alarmKitService.requestAuthorization()
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
                                        toggleAlarm(alarm, isEnabled: newValue)
                                    }
                                ))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                alarmToEdit = alarm
                                showingEditSheet = true
                            }
                        }
                        .onDelete(perform: deleteAlarms)
                    }
                }
                
                // 3. iOS 26 System Queue Monitor
                Section(header: Text("iOS 26 底部系统闹钟同步队列 (AlarmKit)")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.blue)
                            Text("系统级活动队列")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(alarmKitService.isAuthorized ? "状态: 正常运行" : "状态: 未授权")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(alarmKitService.isAuthorized ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .foregroundColor(alarmKitService.isAuthorized ? .green : .red)
                                .cornerRadius(4)
                        }
                        
                        if alarmKitService.systemAlarms.isEmpty {
                            Text("当前系统队列无来自此应用的闹钟。请启用或添加闹钟以同步。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(alarmKitService.systemAlarms) { sysAlarm in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 8) {
                                                Text(sysAlarm.time)
                                                    .font(.system(.subheadline, design: .monospaced))
                                                    .fontWeight(.bold)
                                                Text(sysAlarm.title)
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                    .padding(.horizontal, 4)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(3)
                                            }
                                            Text("ID: \(sysAlarm.id.uuidString.prefix(8))... (由系统接管)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(sysAlarm.repeatString)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("YaClock")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        alarmToEdit = nil
                        showingEditSheet = true
                    }) {
                        Label("添加闹钟", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                AlarmEditSheet(alarmToEdit: alarmToEdit)
            }
            .onAppear {
                alarmKitService.checkAuthorization()
            }
        }
    }
    
    private func toggleAlarm(_ alarm: LocalAlarm, isEnabled: Bool) {
        alarm.isEnabled = isEnabled
        try? modelContext.save()
        
        Task {
            if isEnabled {
                try? await alarmKitService.scheduleAlarm(alarm)
            } else {
                try? await alarmKitService.cancelAlarm(id: alarm.id)
            }
        }
    }
    
    private func deleteAlarms(offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            Task {
                try? await alarmKitService.cancelAlarm(id: alarm.id)
            }
            modelContext.delete(alarm)
        }
        try? modelContext.save()
    }
    
    private func formatRepeatDays(_ days: [Int]) -> String {
        if days.isEmpty { return "只响一次" }
        if days.count == 7 { return "每天" }
        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return days.sorted().map { weekdayNames[$0 - 1] }.joined(separator: " ")
    }
}
