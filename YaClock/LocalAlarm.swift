// MARK: - Data Layer · SwiftData Model
import Foundation
import SwiftData

@Model
final class LocalAlarm {
    var id: UUID
    var hour: Int
    var minute: Int
    var repeatDays: [Int] // 1: Sunday, 2: Monday, ..., 7: Saturday
    var label: String
    var isEnabled: Bool
    var soundName: String

    init(id: UUID = UUID(), hour: Int = 8, minute: Int = 0, repeatDays: [Int] = [], label: String = "闹钟", isEnabled: Bool = true, soundName: String = "默认") {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.label = label
        self.isEnabled = isEnabled
        self.soundName = soundName
    }
}

// MARK: - Domain Mapping
extension LocalAlarm {
    /// LocalAlarm → AlarmEntity（Domain 层值类型）
    var asEntity: AlarmEntity {
        AlarmEntity(
            id: id, hour: hour, minute: minute,
            repeatDays: repeatDays, label: label,
            isEnabled: isEnabled, soundName: soundName
        )
    }

    /// 从 AlarmEntity 创建 LocalAlarm
    convenience init(from entity: AlarmEntity) {
        self.init(
            id: entity.id, hour: entity.hour, minute: entity.minute,
            repeatDays: entity.repeatDays, label: entity.label,
            isEnabled: entity.isEnabled, soundName: entity.soundName
        )
    }

    /// 用 AlarmEntity 的值原地更新自身字段
    func update(from entity: AlarmEntity) {
        hour = entity.hour
        minute = entity.minute
        repeatDays = entity.repeatDays
        label = entity.label
        isEnabled = entity.isEnabled
        soundName = entity.soundName
    }
}

