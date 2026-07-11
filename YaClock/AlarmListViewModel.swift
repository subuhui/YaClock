import Foundation
import SwiftData
import Observation
import Combine

@Observable
@MainActor
final class AlarmListViewModel {
    private let modelContext: ModelContext
    private let alarmService: AlarmServiceProtocol
    
    var isAuthorized: Bool = false
    var systemAlarms: [SystemAlarmInfo] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext, alarmService: AlarmServiceProtocol = AlarmKitService.shared) {
        self.modelContext = modelContext
        self.alarmService = alarmService
        
        self.isAuthorized = alarmService.isAuthorized
        self.systemAlarms = alarmService.systemAlarms
        
        // Listen to changes in the service dynamically if it's an ObservableObject
        if let observableService = alarmService as? AlarmKitService {
            observableService.$isAuthorized
                .receive(on: DispatchQueue.main)
                .sink { [weak self] val in
                    self?.isAuthorized = val
                }
                .store(in: &cancellables)
                
            observableService.$systemAlarms
                .receive(on: DispatchQueue.main)
                .sink { [weak self] alarms in
                    self?.systemAlarms = alarms
                }
                .store(in: &cancellables)
        }
    }
    
    func checkAuthorization() {
        alarmService.checkAuthorization()
    }
    
    func requestAuthorization() async {
        _ = await alarmService.requestAuthorization()
    }
    
    func toggleAlarm(_ alarm: LocalAlarm, isEnabled: Bool) {
        alarm.isEnabled = isEnabled
        try? modelContext.save()
        
        Task {
            if isEnabled {
                try? await alarmService.scheduleAlarm(alarm)
            } else {
                try? await alarmService.cancelAlarm(id: alarm.id)
            }
        }
    }
    
    func deleteAlarms(at offsets: IndexSet, from alarmsList: [LocalAlarm]) {
        for index in offsets {
            guard index < alarmsList.count else { continue }
            let alarm = alarmsList[index]
            Task {
                try? await alarmService.cancelAlarm(id: alarm.id)
            }
            modelContext.delete(alarm)
        }
        try? modelContext.save()
    }
}
