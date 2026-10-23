import SwiftUI

struct VacationView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var schedules: [Schedule] = []
    @State private var selected: Set<UUID> = []
    @State private var start = Calendar.current.startOfDay(for: Date())
    @State private var end = Calendar.current.startOfDay(for: Date())
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("开始日期", selection: $start, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    DatePicker("结束日期", selection: $end, in: start..., displayedComponents: .date)
                } footer: {
                    Text("含起止日。休假期间暂停所选作息，预先设置假期结束后的闹钟，保存同步成功后无需在结束当天打开应用。")
                }
                Section("暂停哪些作息") {
                    if schedules.isEmpty { Text("请先创建作息").foregroundStyle(.secondary) }
                    ForEach(schedules) { schedule in
                        Toggle(schedule.name, isOn: Binding(
                            get: { selected.contains(schedule.id) },
                            set: { value in
                                if value { selected.insert(schedule.id) } else { selected.remove(schedule.id) }
                            }))
                    }
                }
                Section("已安排的休假") {
                    ForEach(schedules.filter { ($0.vacationEnd ?? .distantPast) >= Calendar.current.startOfDay(for: Date()) }) { schedule in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(schedule.name).font(.headline)
                            if let start = schedule.vacationStart, let end = schedule.vacationEnd {
                                Text("\(start.formatted(date: .abbreviated, time: .omitted)) 至 \(end.formatted(date: .abbreviated, time: .omitted))")
                            }
                            Button("结束休假，恢复作息") { saveVacation(clearing: schedule.id) }
                                .disabled(isSaving)
                        }
                    }
                }
                if let message { Section { Text(message).foregroundStyle(.red) } }
            }
            .navigationTitle("休假模式")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") { saveVacation() }
                        .disabled(selected.isEmpty || isSaving || end < start)
                }
            }
            .onChange(of: start) { _, value in if end < value { end = value } }
            .task { load() }
        }
    }

    private func load() {
        do { schedules = try container.scheduleRepo.fetchAll() }
        catch { message = error.localizedDescription }
    }

    private func saveVacation(clearing id: UUID? = nil) {
        isSaving = true
        message = nil
        Task {
            do {
                for var schedule in schedules where id == nil ? selected.contains(schedule.id) : schedule.id == id {
                    schedule.vacationStart = id == nil ? start : nil
                    schedule.vacationEnd = id == nil ? end : nil
                    try container.scheduleRepo.save(schedule)
                }
                load()
                try await container.refreshUseCase.execute()
                if id == nil { dismiss() }
            } catch {
                message = "休假设置未完全同步：\(error.localizedDescription)。请重试同步。"
                load()
            }
            isSaving = false
        }
    }
}
