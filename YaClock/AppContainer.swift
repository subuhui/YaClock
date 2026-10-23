// @Author subuhui
// @Date 2026/7/12 11:28
// @Description 应用级依赖容器，统一组装所有 UseCase 和 Repository，并根据运行环境选择调度器

import Foundation
import SwiftData
import BackgroundTasks
import AlarmKit

/// 应用依赖容器，在 App 入口构造，通过 Environment 注入到所有视图
@Observable
final class AppContainer {

    // MARK: - Repositories
    let scheduleRepo: ScheduleRepository
    let overrideRepo: OverrideRepository
    let occurrenceRepo: ScheduledOccurrenceRepository

    // MARK: - Scheduler
    let scheduler: AlarmScheduler

    // MARK: - UseCases
    let refreshUseCase: RefreshScheduledAlarmsUseCase
    let saveScheduleUseCase: SaveScheduleUseCase
    let deleteScheduleUseCase: DeleteScheduleUseCase
    let toggleScheduleUseCase: ToggleScheduleUseCase
    let saveOverrideUseCase: SaveOverrideUseCase
    let deleteOverrideUseCase: DeleteOverrideUseCase

    // MARK: - Shared State
    let accentColorManager = AccentColorManager()

    /// 初始化依赖容器
    /// - Parameters:
    ///   - context: SwiftData ModelContext
    ///   - scheduler: 根据运行环境注入的调度器（真机 AlarmKitScheduler / 模拟器 InMemoryAlarmScheduler）
    init(context: ModelContext, scheduler: AlarmScheduler) {
        self.scheduler = scheduler

        self.scheduleRepo = ScheduleRepository(context: context)
        self.overrideRepo = OverrideRepository(context: context)
        self.occurrenceRepo = ScheduledOccurrenceRepository(context: context)

        self.refreshUseCase = RefreshScheduledAlarmsUseCase(
            scheduleRepo: scheduleRepo,
            overrideRepo: overrideRepo,
            occurrenceRepo: occurrenceRepo,
            scheduler: scheduler
        )

        self.saveScheduleUseCase = SaveScheduleUseCase(
            scheduleRepo: scheduleRepo,
            refreshUseCase: refreshUseCase
        )

        self.deleteScheduleUseCase = DeleteScheduleUseCase(
            scheduleRepo: scheduleRepo,
            overrideRepo: overrideRepo,
            occurrenceRepo: occurrenceRepo,
            refreshUseCase: refreshUseCase
        )

        self.toggleScheduleUseCase = ToggleScheduleUseCase(
            scheduleRepo: scheduleRepo,
            refreshUseCase: refreshUseCase
        )

        self.saveOverrideUseCase = SaveOverrideUseCase(
            overrideRepo: overrideRepo,
            refreshUseCase: refreshUseCase
        )

        self.deleteOverrideUseCase = DeleteOverrideUseCase(
            overrideRepo: overrideRepo,
            refreshUseCase: refreshUseCase
        )
    }
    func refreshInBackground() async {
        do { try await refreshUseCase.execute() }
        catch { /* 失败原因已保存在 refreshUseCase，首页提供重试入口。 */ }
        scheduleBackgroundRefresh()
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.subuhui.YaClock.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { backgroundRefreshError = error.localizedDescription }
    }

    private(set) var backgroundRefreshError: String?

    func observeSystemAlarms() async {
        #if !targetEnvironment(simulator)
        for await _ in AlarmManager.shared.alarmUpdates {
            if Task.isCancelled { return }
            await refreshUseCase.verifyQueue()
        }
        #endif
    }

}
