// @Author zhangzheming
// @Date 2026/10/22 22:32
// @Description 展示系统闹钟贪睡期间的锁屏与灵动岛倒计时

import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct YaClockAlarmWidget: Widget {
    /// AlarmKit 倒计时要求提供 Live Activity，避免贪睡期间闹钟被系统提前关闭
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<EmptyMetadata>.self) { context in
            HStack {
                Label("贪睡中", systemImage: "zzz")
                Spacer()
                countdown(for: context.state)
            }
            .font(.title2)
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("贪睡中", systemImage: "zzz")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(for: context.state)
                }
            } compactLeading: {
                Image(systemName: "zzz")
            } compactTrailing: {
                countdown(for: context.state)
                    .frame(width: 60)
            } minimal: {
                Image(systemName: "zzz")
            }
        }
    }

    /// 使用系统提供的结束时间持续刷新，无需主应用在后台运行
    @ViewBuilder
    private func countdown(for state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true)
                .monospacedDigit()
        case .paused:
            Text("已暂停")
        case .alert:
            Text("响铃中")
        @unknown default:
            Text("闹钟")
        }
    }
}
