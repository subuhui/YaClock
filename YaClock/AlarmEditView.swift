// MARK: - Presentation Layer · AlarmEdit View
import SwiftUI

struct AlarmEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AlarmEditViewModel
    @State private var isSaving = false
    @State private var saveError: String?

    private let weekdays = [
        (1, "日"), (2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六")
    ]

    init(editingAlarm: LocalAlarm?, repository: AlarmRepository) {
        let entity = editingAlarm?.asEntity
        _viewModel = State(initialValue: AlarmEditViewModel(editingEntity: entity, repository: repository))
    }

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            Form {
                // 时间选择
                Section {
                    DatePicker("时间", selection: $vm.selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // 基本设置
                Section(header: Text("基本设置")) {
                    TextField("标签", text: $vm.label)
                    Picker("铃声", selection: $vm.soundName) {
                        Text("雷达").tag("雷达")
                        Text("经典经典").tag("经典经典")
                        Text("默认").tag("默认")
                    }
                }

                // 重复
                Section(header: Text("重复")) {
                    HStack(spacing: 8) {
                        ForEach(weekdays, id: \.0) { dayNum, dayName in
                            let selected = viewModel.repeatDays.contains(dayNum)
                            Text(dayName)
                                .font(.subheadline)
                                .fontWeight(selected ? .bold : .regular)
                                .frame(width: 36, height: 36)
                                .background(selected ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selected ? .white : .primary)
                                .clipShape(Circle())
                                .onTapGesture {
                                    if selected {
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

                // 错误提示
                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "编辑闹钟" : "新建闹钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            isSaving = true
                            do {
                                try await viewModel.save()
                                dismiss()
                            } catch {
                                saveError = "保存失败：\(error.localizedDescription)"
                            }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}
