// @Author zhangzheming
// @Date 2026/10/22 22:32
// @Description 展示系统闹钟贪睡期间的锁屏与灵动岛倒计时

import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

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


@main
struct YaClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextAlarmWidget()
        YaClockAlarmWidget()
    }
}

private struct AlarmEntry: TimelineEntry {
    let date: Date
    let snapshot: AlarmWidgetSnapshot?
}

private struct AlarmTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmEntry {
        .init(date: Date(), snapshot: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (AlarmEntry) -> Void) {
        completion(.init(date: Date(), snapshot: AlarmWidgetSnapshot.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmEntry>) -> Void) {
        let now = Date()
        let snapshot = AlarmWidgetSnapshot.read()
        // 每个闹钟过后推进至下一次，主应用关闭期间仍可更新。
        let transitions = (snapshot?.alarms.map { $0.date.addingTimeInterval(1) } ?? []).filter { $0 > now }
        let midnights = (1...60).map { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: now))! }
        let dates = Array(Set([now] + transitions + midnights)).sorted()
        completion(Timeline(entries: dates.map { .init(date: $0, snapshot: snapshot) },
                            policy: .after(now.addingTimeInterval(3600))))
    }
}

struct NextAlarmWidget: Widget {
    let kind = "YaClock.NextAlarm"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmTimelineProvider()) { entry in
            NextAlarmWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("下一次闹钟")
        .description("查看下一次闹钟、明日作息与调休安排。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

private struct NextAlarmWidgetView: View {
    let entry: AlarmEntry
    @Environment(\.widgetFamily) private var family
    private var next: AlarmWidgetSnapshot.Alarm? {
        entry.snapshot?.alarms.first { $0.date > entry.date }
    }
    var body: some View {
        Group {
            if let snapshot = entry.snapshot, entry.date < snapshot.validUntil {
                if family == .accessoryInline {
                    if let next { Text("\(next.label) \(next.date, style: .time)") }
                    else { Text("暂无闹钟") }
                } else if family == .accessoryCircular {
                    VStack {
                        Image(systemName: "alarm")
                        if let next { Text(next.date, style: .time).minimumScaleFactor(0.6) }
                        else { Text("无闹钟").font(.caption) }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("下一次闹钟", systemImage: "alarm").font(.caption)
                        if let next {
                            Text(next.date, style: .time).font(.title).bold().minimumScaleFactor(0.6)
                            Text(next.label).font(.caption).lineLimit(1)
                            if family == .systemSmall || family == .systemMedium {
                                Text(next.date, style: .date).font(.caption)
                                Text(next.confirmed ? snapshot.status : "尚未设置成功，请打开应用")
                                    .font(.caption2).lineLimit(2)
                            }
                        } else { Text("暂无闹钟").font(.headline) }
                        if family == .systemMedium {
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: entry.date)!
                            if let summary = snapshot.daySummaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: tomorrow) }) {
                                Text("明日：" + summary.text).font(.caption).lineLimit(2)
                            } else {
                                Text("打开应用更新明日班次").font(.caption)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Label("打开 YaClock 更新闹钟", systemImage: "alarm").font(.caption)
            }
        }
    }
}
