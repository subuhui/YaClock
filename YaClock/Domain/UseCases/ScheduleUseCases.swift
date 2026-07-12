// @Author subuhui
// @Date 2026/7/12 10:49
// @Description 作息表的增删改启用三个 UseCase，均在执行后触发对账引擎同步系统队列

import Foundation

// MARK: - SaveScheduleUseCase

/// 保存作息表的 UseCase（新建 or 更新），完成后触发对账引擎同步
final class SaveScheduleUseCase {

    private let scheduleRepo: ScheduleRepository
    private let refreshUseCase: RefreshScheduledAlarmsUseCase

    init(scheduleRepo: ScheduleRepository, refreshUseCase: RefreshScheduledAlarmsUseCase) {
        self.scheduleRepo = scheduleRepo
        self.refreshUseCase = refreshUseCase
    }

    /// 保存作息表并触发对账
    /// - Parameter schedule: 需要保存的作息表实体
    func execute(_ schedule: Schedule) async throws {
        try scheduleRepo.save(schedule)
        try await refreshUseCase.execute()
    }
}

// MARK: - DeleteScheduleUseCase

/// 删除作息表的 UseCase，同时清理其所有已调度记录，完成后触发对账引擎同步
final class DeleteScheduleUseCase {

    private let scheduleRepo: ScheduleRepository
    private let overrideRepo: OverrideRepository
    private let occurrenceRepo: ScheduledOccurrenceRepository
    private let refreshUseCase: RefreshScheduledAlarmsUseCase

    init(
        scheduleRepo: ScheduleRepository,
        overrideRepo: OverrideRepository,
        occurrenceRepo: ScheduledOccurrenceRepository,
        refreshUseCase: RefreshScheduledAlarmsUseCase
    ) {
        self.scheduleRepo = scheduleRepo
        self.overrideRepo = overrideRepo
        self.occurrenceRepo = occurrenceRepo
        self.refreshUseCase = refreshUseCase
    }

    /// 删除指定作息表及其所有关联数据，并触发对账
    /// - Parameter id: 要删除的作息表 ID
    func execute(id: UUID) async throws {
        try scheduleRepo.delete(id: id)
        // 清除该作息下的所有已调度记录，对账引擎会接着取消系统队列中的残留
        try occurrenceRepo.deleteAll(for: id)
        try await refreshUseCase.execute()
    }
}

// MARK: - ToggleScheduleUseCase

/// 切换作息表启用/禁用状态的 UseCase，完成后触发对账引擎同步
final class ToggleScheduleUseCase {

    private let scheduleRepo: ScheduleRepository
    private let refreshUseCase: RefreshScheduledAlarmsUseCase

    init(scheduleRepo: ScheduleRepository, refreshUseCase: RefreshScheduledAlarmsUseCase) {
        self.scheduleRepo = scheduleRepo
        self.refreshUseCase = refreshUseCase
    }

    /// 将指定作息表的启用状态取反，并触发对账
    /// - Parameter id: 作息表 ID
    func execute(id: UUID) async throws {
        var schedules = try scheduleRepo.fetchAll()
        guard let index = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[index].isEnabled.toggle()
        try scheduleRepo.save(schedules[index])
        try await refreshUseCase.execute()
    }
}

// MARK: - SaveOverrideUseCase

/// 保存单日临时覆盖的 UseCase，完成后触发对账引擎同步
final class SaveOverrideUseCase {

    private let overrideRepo: OverrideRepository
    private let refreshUseCase: RefreshScheduledAlarmsUseCase

    init(overrideRepo: OverrideRepository, refreshUseCase: RefreshScheduledAlarmsUseCase) {
        self.overrideRepo = overrideRepo
        self.refreshUseCase = refreshUseCase
    }

    /// 保存单日覆盖并触发对账
    func execute(_ override: ScheduleOverride) async throws {
        try overrideRepo.save(override)
        try await refreshUseCase.execute()
    }
}

// MARK: - DeleteOverrideUseCase

/// 删除单日临时覆盖（恢复默认）的 UseCase，完成后触发对账引擎同步
final class DeleteOverrideUseCase {

    private let overrideRepo: OverrideRepository
    private let refreshUseCase: RefreshScheduledAlarmsUseCase

    init(overrideRepo: OverrideRepository, refreshUseCase: RefreshScheduledAlarmsUseCase) {
        self.overrideRepo = overrideRepo
        self.refreshUseCase = refreshUseCase
    }

    /// 删除指定覆盖并触发对账
    func execute(scheduleID: UUID, targetDate: Date) async throws {
        try overrideRepo.delete(scheduleID: scheduleID, targetDate: targetDate)
        try await refreshUseCase.execute()
    }
}
