import SwiftUI

struct AlarmHealthCard: View {
    @Environment(AppContainer.self) private var container
    @State private var permission: AlarmPermission = .notDetermined
    @State private var errorMessage: String?

    var body: some View {
        let health = container.refreshUseCase
        VStack(alignment: .leading, spacing: 10) {
            Label("闹钟保障", systemImage: "checkmark.shield")
                .font(.headline)
            Text(permission.rawValue)
            if permission == .simulated {
                Text("当前为模拟模式，不会实际响铃。")
            }
            if let error = health.errorMessage ?? errorMessage {
                Text("同步失败：" + error).foregroundStyle(.red)
            }
            if let next = health.expected.first(where: { $0.fireDate > Date() }) {
                Label(health.confirmedIDs.contains(next.id) ? "下次闹钟已在队列中" : "下次闹钟尚未成功设置",
                      systemImage: health.confirmedIDs.contains(next.id) ? "checkmark.circle" : "exclamationmark.triangle")
                Text("\(next.label) · \(next.fireDate.formatted(date: .abbreviated, time: .shortened))")
            } else {
                Text(health.lastSync == nil ? "尚未核对系统队列" : "未来 60 天内无闹钟")
            }
            if let through = health.scheduledThrough, health.errorMessage == nil, !health.expected.isEmpty {
                Text("已核对至 \(through.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !health.missingHolidayYears.isEmpty {
                Text("缺少 \(health.missingHolidayYears.map(String.init).joined(separator: "、")) 年节假日数据，暂按普通星期计算。")
                    .foregroundStyle(.orange)
                NavigationLink("更新节假日数据") { HolidayDataView() }
            }
            if let lastSync = health.lastSync {
                Text("上次成功核对：\(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if health.isRefreshing { ProgressView("正在核对系统闹钟…") }
            Button(permission == .notDetermined ? "授权并同步" : "重新同步") {
                Task {
                    do {
                        if permission == .notDetermined { try await health.requestPermission() }
                        else { try await health.execute() }
                        errorMessage = nil
                    } catch { errorMessage = error.localizedDescription }
                    permission = container.scheduler.permission
                }
            }
            .disabled(health.isRefreshing || permission == .denied)
            if permission == .denied {
                Button("打开设置，允许闹钟") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
            Text("打开应用时自动补齐后续闹钟；系统允许时也会在后台刷新。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .task(id: health.isRefreshing) { permission = container.scheduler.permission }
    }
}
