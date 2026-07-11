// MARK: - Data Layer · Repository
import Foundation
import SwiftData
import Combine

/// 聚合 SwiftData 持久化 + AlarmKit 调度的统一仓储实现。
/// 使用 @Observable 使属性变化自动驱动 SwiftUI 视图更新。
@Observable
@MainActor
final class AlarmRepository: AlarmRepositoryProtocol {

    // MARK: 对外可观察状态
    private(set) var systemAlarms: [SystemAlarmInfo] = []
    private(set) var isAuthorized: Bool = false

    // MARK: 私有依赖
    private let modelContext: ModelContext
    private let alarmService: AlarmKitService
    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext, alarmService: AlarmKitService = .shared) {
        self.modelContext = modelContext
        self.alarmService = alarmService

        // 初始化状态同步
        self.isAuthorized = alarmService.isAuthorized
        self.systemAlarms = alarmService.systemAlarms

        // 订阅 AlarmKitService 的 @Published 属性，转发到 @Observable
        alarmService.$isAuthorized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] val in self?.isAuthorized = val }
            .store(in: &cancellables)

        alarmService.$systemAlarms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alarms in self?.systemAlarms = alarms }
            .store(in: &cancellables)
    }

    // MARK: - 持久化

    func save(_ entity: AlarmEntity) throws {
        let id = entity.id
        let descriptor = FetchDescriptor<LocalAlarm>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: entity)   // 更新已有记录
        } else {
            modelContext.insert(LocalAlarm(from: entity))   // 插入新记录
        }
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<LocalAlarm>(
            predicate: #Predicate { $0.id == id }
        )
        if let alarm = try? modelContext.fetch(descriptor).first {
            modelContext.delete(alarm)
            try modelContext.save()
        }
    }

    // MARK: - 调度（委托给 AlarmKitService）

    func scheduleAlarm(_ entity: AlarmEntity) async throws {
        try await alarmService.scheduleAlarm(entity)
    }

    func cancelAlarm(id: UUID) async throws {
        try await alarmService.cancelAlarm(id: id)
    }

    // MARK: - 权限

    func requestAuthorization() async -> Bool {
        let granted = await alarmService.requestAuthorization()
        self.isAuthorized = alarmService.isAuthorized
        return granted
    }

    func checkAuthorization() {
        alarmService.checkAuthorization()
        self.isAuthorized = alarmService.isAuthorized
    }
}
