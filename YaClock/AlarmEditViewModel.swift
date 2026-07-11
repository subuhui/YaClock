import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AlarmEditViewModel {
    private let modelContext: ModelContext
    private let alarmService: AlarmServiceProtocol
    let alarmToEdit: LocalAlarm?
    
    var selectedTime = Date()
    var label = "闹钟"
    var repeatDays: Set<Int> = [] // 1: Sunday, ..., 7: Saturday
    var soundName = "默认"
    
    init(modelContext: ModelContext, alarmToEdit: LocalAlarm?, alarmService: AlarmServiceProtocol = AlarmKitService.shared) {
        self.modelContext = modelContext
        self.alarmToEdit = alarmToEdit
        self.alarmService = alarmService
        
        if let alarm = alarmToEdit {
            self.label = alarm.label
            self.repeatDays = Set(alarm.repeatDays)
            self.soundName = alarm.soundName
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = alarm.hour
            components.minute = alarm.minute
            if let date = Calendar.current.date(from: components) {
                self.selectedTime = date
            }
        }
    }
    
    func saveAlarm() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        let sortedDays = Array(repeatDays).sorted()
        
        let alarm: LocalAlarm
        if let alarmToEdit = alarmToEdit {
            alarmToEdit.hour = hour
            alarmToEdit.minute = minute
            alarmToEdit.repeatDays = sortedDays
            alarmToEdit.label = label
            alarmToEdit.soundName = soundName
            alarm = alarmToEdit
        } else {
            alarm = LocalAlarm(
                hour: hour,
                minute: minute,
                repeatDays: sortedDays,
                label: label,
                isEnabled: true,
                soundName: soundName
            )
            modelContext.insert(alarm)
        }
        
        try? modelContext.save()
        
        if alarm.isEnabled {
            Task {
                try? await alarmService.scheduleAlarm(alarm)
            }
        }
    }
}
