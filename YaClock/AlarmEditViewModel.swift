// MARK: - Presentation Layer · AlarmEdit
import Foundation

/// 闹钟编辑页的 ViewModel。
/// 通过 SaveAlarmUseCase 保存，不直接持有 ModelContext 或 AlarmKitService。
@Observable
@MainActor
final class AlarmEditViewModel {

    // MARK: 编辑状态
    var selectedTime = Date()
    var label = "闹钟"
    var repeatDays: Set<Int> = []   // 1: Sunday … 7: Saturday
    var soundName = "默认"

    // MARK: 只读
    let isEditing: Bool

    // MARK: 私有
    private let editingEntity: AlarmEntity?
    private let saveUseCase: SaveAlarmUseCase

    init(editingEntity: AlarmEntity?, repository: AlarmRepository) {
        self.editingEntity = editingEntity
        self.isEditing = editingEntity != nil
        self.saveUseCase = SaveAlarmUseCase(repository: repository)

        if let entity = editingEntity {
            label = entity.label
            repeatDays = Set(entity.repeatDays)
            soundName = entity.soundName

            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = entity.hour
            components.minute = entity.minute
            selectedTime = Calendar.current.date(from: components) ?? Date()
        }
    }

    // MARK: - 意图

    func save() async throws {
        let cal = Calendar.current
        let entity = AlarmEntity(
            id: editingEntity?.id ?? UUID(),
            hour: cal.component(.hour, from: selectedTime),
            minute: cal.component(.minute, from: selectedTime),
            repeatDays: Array(repeatDays).sorted(),
            label: label,
            isEnabled: editingEntity?.isEnabled ?? true,
            soundName: soundName
        )
        try await saveUseCase.execute(entity)
    }
}
