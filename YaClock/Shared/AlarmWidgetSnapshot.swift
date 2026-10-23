import Foundation

/// 主应用与 Widget 扩展通过 App Group 共享只读快照。
struct AlarmWidgetSnapshot: Codable {
    struct Alarm: Codable {
        let date: Date
        let label: String
        let confirmed: Bool
    }
    struct DaySummary: Codable {
        let date: Date
        let text: String
    }
    let daySummaries: [DaySummary]
    static let groupID = "group.com.subuhui.YaClock"
    static let key = "alarm.widget.snapshot.v1"
    let generatedAt: Date
    let validUntil: Date
    let alarms: [Alarm]
    let status: String

    static func read() -> Self? {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func write() throws {
        let data = try JSONEncoder().encode(self)
        UserDefaults(suiteName: Self.groupID)!.set(data, forKey: Self.key)
    }
}
