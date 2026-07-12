// @Author subuhui
// @Date 2026/7/12 12:00
// @Description 调试监视器视图，展示当前数据库已记录的已调度实例，并可与 scheduler 真实队列对照

import SwiftUI
import SwiftData

struct SystemMonitorView: View {
    @Environment(AppContainer.self) private var container
    @State private var scheduledItems: [LocalScheduledOccurrence] = []
    @State private var actualSchedulerIDs: Set<UUID> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    refresh()
                } label: {
                    HStack {
                        Label("刷新状态", systemImage: "arrow.clockwise")
                        Spacer()
                        if isLoading {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                } header: {
                    Text("错误")
                }
            }

            Section {
                if scheduledItems.isEmpty {
                    Text("没有已调度的闹钟记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(scheduledItems, id: \.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timeString(from: item.fireDate))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                                
                                Text("作息 ID: \(item.scheduleID.uuidString.prefix(8))...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text("实例 ID: \(item.id.uuidString.prefix(8))...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            
                            // 检查该 ID 是否在实际 scheduler 队列中
                            if actualSchedulerIDs.contains(item.id) {
                                Label("已下发系统", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Label("系统队列缺失", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("数据库已调度映射 (\(scheduledItems.count) 个)")
            }

            Section {
                let diff = actualSchedulerIDs.subtracting(Set(scheduledItems.map { $0.id }))
                if diff.isEmpty {
                    Text("无系统残留")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(diff), id: \.self) { id in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("未知闹钟 ID: \(id.uuidString)")
                                .font(.caption)
                            Text("在系统/模拟器队列中，但数据库无对应记录")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("系统残留对比")
            }
        }
        .navigationTitle("调度监视器")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                scheduledItems = try container.occurrenceRepo.fetchAll().sorted(by: { $0.fireDate < $1.fireDate })
                actualSchedulerIDs = try await container.scheduler.scheduledIDs()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}
