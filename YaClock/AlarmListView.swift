// MARK: - Presentation Layer · AlarmList View
import SwiftUI
import SwiftData

struct AlarmListView: View {
    @Query(sort: \LocalAlarm.hour) private var alarms: [LocalAlarm]
    @State private var viewModel: AlarmListViewModel

    private let repository: AlarmRepository

    struct SheetItem: Identifiable {
        let id = UUID()
        let alarm: LocalAlarm?
    }
    @State private var activeSheet: SheetItem?

    init(repository: AlarmRepository) {
        self.repository = repository
        _viewModel = State(initialValue: AlarmListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            List {
                // 1. 权限提示横幅
                if !viewModel.isAuthorized {
                    authorizationBanner
                }

                // 2. 我的闹钟
                Section(header: Text("我的闹钟")) {
                    if alarms.isEmpty {
                        ContentUnavailableView(
                            "无闹钟",
                            systemImage: "alarm",
                            description: Text("点击右上角 + 按钮添加一个闹钟")
                        )
                    } else {
                        ForEach(alarms) { alarm in
                            alarmRow(alarm)
                        }
                        .onDelete { offsets in
                            let toDelete = offsets.map { alarms[$0].asEntity }
                            viewModel.deleteAlarms(toDelete)
                        }
                    }
                }

                // 3. 系统队列监控
                SystemMonitorView(
                    systemAlarms: viewModel.systemAlarms,
                    isAuthorized: viewModel.isAuthorized
                )
            }
            .navigationTitle("YaClock")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = SheetItem(alarm: nil)
                    } label: {
                        Label("添加闹钟", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { item in
                AlarmEditView(editingAlarm: item.alarm, repository: repository)
                    .id(item.id)
            }
            .onAppear {
                viewModel.checkAuthorization()
            }
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var authorizationBanner: some View {
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
                Button {
                    Task { await viewModel.requestAuthorization() }
                } label: {
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

    @ViewBuilder
    private func alarmRow(_ alarm: LocalAlarm) -> some View {
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
                    viewModel.toggleAlarm(alarm.asEntity, isEnabled: newValue)
                }
            ))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = SheetItem(alarm: alarm)
        }
    }

    // MARK: - Helpers

    private func formatRepeatDays(_ days: [Int]) -> String {
        if days.isEmpty { return "只响一次" }
        if days.count == 7 { return "每天" }
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return days.sorted().map { names[$0 - 1] }.joined(separator: " ")
    }
}
