import SwiftUI

struct SystemMonitorView: View {
    let systemAlarms: [SystemAlarmInfo]
    let isAuthorized: Bool
    
    var body: some View {
        Section(header: Text("iOS 26 底部系统闹钟同步队列 (AlarmKit)")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text("系统级活动队列")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(isAuthorized ? "状态: 正常运行" : "状态: 未授权")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isAuthorized ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(isAuthorized ? .green : .red)
                        .cornerRadius(4)
                }
                
                if systemAlarms.isEmpty {
                    Text("当前系统队列无来自此应用的闹钟。请启用或添加闹钟以同步。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(systemAlarms) { sysAlarm in
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
}
