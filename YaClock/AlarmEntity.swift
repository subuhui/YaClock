// MARK: - Domain Layer
import Foundation

/// 纯值类型的业务模型，与持久化框架完全解耦。
/// ViewModel 和 UseCase 只与此类型交互。
struct AlarmEntity: Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var hour: Int
    var minute: Int
    var repeatDays: [Int]   // 1: Sunday … 7: Saturday
    var label: String
    var isEnabled: Bool
    var soundName: String

    init(
        id: UUID = UUID(),
        hour: Int = 8,
        minute: Int = 0,
        repeatDays: [Int] = [],
        label: String = "闹钟",
        isEnabled: Bool = true,
        soundName: String = "默认"
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.label = label
        self.isEnabled = isEnabled
        self.soundName = soundName
    }
}
