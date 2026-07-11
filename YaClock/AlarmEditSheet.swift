import SwiftUI
import SwiftData

struct AlarmEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var alarmToEdit: LocalAlarm?
    
    @State private var selectedTime = Date()
    @State private var label = "闹钟"
    @State private var repeatDays: Set<Int> = [] // 1: Sunday, ..., 7: Saturday
    @State private var soundName = "默认"
    
    private let weekdays = [
        (1, "日"), (2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("时间", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section(header: Text("基本设置")) {
                    TextField("标签", text: $label)
                    
                    Picker("铃声", selection: $soundName) {
                        Text("雷达").tag("雷达")
                        Text("经典经典").tag("经典经典")
                        Text("默认").tag("默认")
                    }
                }
                
                Section(header: Text("重复")) {
                    HStack(spacing: 8) {
                        ForEach(weekdays, id: \.0) { dayNum, dayName in
                            Text(dayName)
                                .font(.subheadline)
                                .fontWeight(repeatDays.contains(dayNum) ? .bold : .regular)
                                .frame(width: 36, height: 36)
                                .background(repeatDays.contains(dayNum) ? Color.blue : Color(.systemGray6))
                                .foregroundColor(repeatDays.contains(dayNum) ? .white : .primary)
                                .clipShape(Circle())
                                .onTapGesture {
                                    if repeatDays.contains(dayNum) {
                                        repeatDays.remove(dayNum)
                                    } else {
                                        repeatDays.insert(dayNum)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle(alarmToEdit == nil ? "新建闹钟" : "编辑闹钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAlarm()
                    }
                }
            }
            .onAppear {
                if let alarm = alarmToEdit {
                    label = alarm.label
                    repeatDays = Set(alarm.repeatDays)
                    soundName = alarm.soundName
                    
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    components.hour = alarm.hour
                    components.minute = alarm.minute
                    if let date = Calendar.current.date(from: components) {
                        selectedTime = date
                    }
                }
            }
        }
    }
    
    private func saveAlarm() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        let sortedDays = Array(repeatDays).sorted()
        
        let alarm: LocalAlarm
        if let alarmToEdit = alarmToEdit {
            alarmToEdit.hour = hour
            alarmToEdit.minute = minute
            alarmToEdit.repeatDays = sortedDays
            alarmToEdit.label = label
            alarmToEdit.soundName = soundName
            alarm = alarmToEdit
        } else {
            alarm = LocalAlarm(
                hour: hour,
                minute: minute,
                repeatDays: sortedDays,
                label: label,
                isEnabled: true,
                soundName: soundName
            )
            modelContext.insert(alarm)
        }
        
        try? modelContext.save()
        
        if alarm.isEnabled {
            Task {
                try? await AlarmKitService.shared.scheduleAlarm(alarm)
            }
        }
        
        dismiss()
    }
}
