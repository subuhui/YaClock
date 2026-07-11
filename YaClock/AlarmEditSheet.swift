import SwiftUI
import SwiftData

struct AlarmEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AlarmEditViewModel
    
    private let weekdays = [
        (1, "日"), (2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六")
    ]
    
    init(modelContext: ModelContext, alarmToEdit: LocalAlarm?) {
        _viewModel = State(initialValue: AlarmEditViewModel(modelContext: modelContext, alarmToEdit: alarmToEdit))
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        return NavigationStack {
            Form {
                Section {
                    DatePicker("时间", selection: $viewModel.selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section(header: Text("基本设置")) {
                    TextField("标签", text: $viewModel.label)
                    
                    Picker("铃声", selection: $viewModel.soundName) {
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
                                .fontWeight(viewModel.repeatDays.contains(dayNum) ? .bold : .regular)
                                .frame(width: 36, height: 36)
                                .background(viewModel.repeatDays.contains(dayNum) ? Color.blue : Color(.systemGray6))
                                .foregroundColor(viewModel.repeatDays.contains(dayNum) ? .white : .primary)
                                .clipShape(Circle())
                                .onTapGesture {
                                    if viewModel.repeatDays.contains(dayNum) {
                                        viewModel.repeatDays.remove(dayNum)
                                    } else {
                                        viewModel.repeatDays.insert(dayNum)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle(viewModel.alarmToEdit == nil ? "新建闹钟" : "编辑闹钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await viewModel.saveAlarm()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
