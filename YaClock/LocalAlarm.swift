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
