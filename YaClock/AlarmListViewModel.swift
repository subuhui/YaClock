// MARK: - Presentation Layer · AlarmList
import Foundation

/// 闹钟列表页的 ViewModel。
/// 只持有 AlarmRepository（@Observable）并调用 UseCase，不直接接触 SwiftData/AlarmKit。
@Observable
@MainActor
final class AlarmListViewModel {

    // MARK: 对外状态（从 repository 派生，@Observable 自动追踪）
    var systemAlarms: [SystemAlarmInfo] { repository.systemAlarms }
    var isAuthorized: Bool { repository.isAuthorized }

    // MARK: 私有依赖
    private let repository: AlarmRepository
    private let toggleUseCase: ToggleAlarmUseCase
    private let deleteUseCase: DeleteAlarmUseCase

    init(repository: AlarmRepository) {
        self.repository = repository
        self.toggleUseCase = ToggleAlarmUseCase(repository: repository)
        self.deleteUseCase = DeleteAlarmUseCase(repository: repository)
    }

    // MARK: - 意图

    func toggleAlarm(_ entity: AlarmEntity, isEnabled: Bool) {
        Task {
            try? await toggleUseCase.execute(alarm: entity, isEnabled: isEnabled)
        }
    }

    func deleteAlarms(_ entities: [AlarmEntity]) {
        Task {
            for entity in entities {
                try? await deleteUseCase.execute(id: entity.id)
            }
        }
    }

    func requestAuthorization() async {
        _ = await repository.requestAuthorization()
    }

    func checkAuthorization() {
        repository.checkAuthorization()
    }
}
