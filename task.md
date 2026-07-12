# YaClock v2.0 重构任务拆分与实现细节清单

本规划将重构任务按功能拆分为 7 个模块，并细化出具体的实现路径�### 1.1 LocalTime, AlarmSound, SnoozeConfiguration
- [x] 创建 [LocalTime.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Schedule/LocalTime.swift)
  - 实现结构体 `LocalTime`，包含 `hour: Int` 和 `minute: Int`，遵循 `Codable`, `Hashable`, `Sendable`。
- [x] 创建 [AlarmSound.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Schedule/AlarmSound.swift)
  - 实现结构体 `AlarmSound`，包含 `name: String`，以及枚举 `SoundType` (`system`, `custom`)。
- [x] 创建 [SnoozeConfiguration.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Schedule/SnoozeConfiguration.swift)
  - 实现结构体 `SnoozeConfiguration`，包含 `isEnabled: Bool`，和 `durationMinutes: Int`。

### 1.2 ScheduleRule (作息规则枚举)
- [x] 创建 [ScheduleRule.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Schedule/ScheduleRule.swift)
  - 实现 `ScheduleRule` 枚举及各子规则结构：
    - `once(OnceRule)`: 包含 `date: Date`。
    - `weekly(WeeklyRule)`: 包含 `repeatDays: [Int]` (1-7, 1=周日)。
    - `chineseWorkday(ChineseWorkdayRule)`: 包含 `policy`（跟调休 `.followHoliday`、只跳节假日 `.skipHoliday`、忽略节假日 `.ignoreHoliday`）和基础 `repeatDays: [Int]`。
    - `alternatingWeeks(AlternatingWeeksRule)`: 包含 `anchorDate: Date`，`anchorWeekType: WeekType` (`.weekA` / `.weekB`)，`weekAWorkdays: [Int]`，`weekBWorkdays: [Int]`。
    - `cycle(CycleRule)`: 包含 `anchorDate: Date`，以及周期数组 `cycleDays: [CycleDay]`。
      - `CycleDay`: 包含 `name: String`，`isWorking: Bool`，`isRinging: Bool`，`timeOverride: LocalTime?`。

### 1.3 Schedule (长期作息表) 与 Override (单日临时覆盖)
- [x] 创建 [Schedule.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Schedule/Schedule.swift)
  - 实现核心作息结构，包含：`id`，`name`，`time`，`rule`，`sound`，`snooze`，`isEnabled` commod，`startDate`，`endDate` 等。
- [x] 创建 [ScheduleOverride.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Override/ScheduleOverride.swift)
  - 实现结构体 `ScheduleOverride`，表达单日临时调整。
  - 行动类型 `Action` 枚举：`.skip`，`.forceWorking`，`.changeTime(LocalTime)`。

### 1.4 AlarmOccurrence (具体响铃实例)
- [x] 创建 [AlarmOccurrence.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Occurrence/AlarmOccurrence.swift)
  - 定义 `AlarmOccurrence`，代表最终用于调度的闹钟实例。包含稳定 ID 的 SHA256 计算方法：
    ```swift
    static func generateStableID(scheduleID: UUID, fireDate: Date) -> UUID
    ```ject/YaClock/YaClock/Domain/Override/ScheduleOverride.swift)
  - 实现结构体 `ScheduleOverride`，表达单日临时调整。
  - 行动类型 `Action` 枚举：`.skip`，`.forceWorking`，`.changeTime(LocalTime)`。

### 1.4 AlarmOccurrence (具体响铃实例)
- [x] 创建 [AlarmOccurrence.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Occurrence/AlarmOccurrence.swift)
  - 定义 `AlarmOccurrence`，代表最终用于调度的闹钟实例。包含稳定 ID 的 SHA256 计算方法：
    ```swift
    static func generateStableID(scheduleID: UUID, fireDate: Date) -> UUID
    ```

---

## 模块 2：规则引擎 (Rule Engine) 与节假日计算

本模块是核心业务能力，通过纯 Swift 计算产生指定时间区间的闹铃实例。

### 2.1 节假日数据源
- [x] 创建 [HolidayProvider.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Infrastructure/Holiday/HolidayProvider.swift)
  - 内置 2026 全年法定节假日和补班数据表。
  - 提供 `checkHoliday(on date: Date) -> HolidayType?`：返回 `.holiday(name)` 或 `.workday(name)`。

### 2.2 规则引擎计算器
- [x] 创建 [RuleEngine.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/RuleEngine/RuleEngine.swift)
  - 实现 `generateOccurrences(for:overrides:holidays:in:calendar:)` 方法。
  - 核心计算子路径：
    - **Weekly**: 按工作日列表过滤。
    - **Chinese Workday**: 结合 `HolidayProvider` 过滤法定休假，并添加补班日期。
    - **Alternating Weeks (大小周)**：根据 `anchorDate` 计算与目标日期相差的周数，判断是 A 周还是 B 周，应用对应的 repeatDays。
    - **Cycle (轮班循环)**：根据 `anchorDate` 计算与目标日期相差的绝对天数，取余得到周期索引，提取对应的 `CycleDay` 响铃状态和时间覆盖。
    - **Override 应用**：最后合并 `[ScheduleOverride]`，如果有 `.skip` 则删除该天实例，如果有 `.changeTime` 则修改该天实例时间，如果有 `.forceWorking` 且原规则该天不响，则强行追加该天的实例。

---

## 模块 3：持久化与调度层 (Infrastructure)

实现底层的实体存取和系统 API 调度，隔离平台差异。

### 3.1 SwiftData 本地模型
- [x] 创建 [LocalModels.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Infrastructure/Persistence/LocalModels.swift)
  - `@Model` 标注类 `LocalSchedule`（将 `ScheduleRule` 编码为 JSON 二进制数据存储）。
  - `@Model` 标注类 `LocalScheduleOverride`。
  - `@Model` 标注类 `LocalScheduledOccurrence`（存储已经成功下发到 AlarmKit 的映射）。

### 3.2 仓储实现
- [x] 创建 [PersistenceRepositories.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Infrastructure/Persistence/PersistenceRepositories.swift)
  - 实现 `ScheduleRepository` 和 `OverrideRepository`，以 `ModelContext` 为输入进行 CRUD。

### 3.3 系统级闹钟调度适配 (AlarmKit & 模拟器模拟)
- [x] 创建 [AlarmScheduler.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/Scheduler/AlarmScheduler.swift) 协议。
- [x] 创建 [AlarmKitScheduler.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Infrastructure/AlarmKit/AlarmKitScheduler.swift)
  - 真机适配器：将我们的 `AlarmOccurrence` 转为 AlarmKit 的 `AlarmConfiguration` 并注册。
- [x] 创建 [InMemoryAlarmScheduler.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Infrastructure/AlarmKit/InMemoryAlarmScheduler.swift)
  - 模拟器适配器：在内存中用 `[SystemAlarmInfo]` 数组维护虚拟队列，模拟授权状态和 `schedule`/`cancel` 成功。

---

## 模块 4：对账引擎 (Reconciliation Engine)

这是保障 App 离线运行和防漏响的关键。

### 4.1 Diff 计算与同步对账
- [x] 创建 [RefreshScheduledAlarmsUseCase.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/UseCases/RefreshScheduledAlarmsUseCase.swift)
  - 计算未来 60 天内所有启用的 Schedule 的预期 Occurrences。
  - 读取当前 `LocalScheduledOccurrence` 映射及 `AlarmScheduler` 中的真实队列。
  - 计算三个差集：
    - `toSchedule`：在预期中，但系统队列未调度的实例 -> 调用 `scheduler.schedule(...)`。
    - `toCancel`：系统队列里有多余的，或者作息被关闭/临时跳过而不再需要的实例 -> 调用 `scheduler.cancel(...)`。
    - `toUpdate`：时间或铃声与预期不符的实例。
  - 对账完成后更新 SwiftData 中的 `LocalScheduledOccurrence`。
- [x] 创建 [ScheduleUseCases.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Domain/UseCases/ScheduleUseCases.swift)
  - 整合 `SaveScheduleUseCase`、`DeleteScheduleUseCase`、`ToggleScheduleUseCase`，它们均在执行后触发 `RefreshScheduledAlarmsUseCase`。

---

## 模块 5：Shared 与主题配色管理 (Shared & Theme)

### 5.1 One Accent 机制
- [x] 创建 [AccentColorManager.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Shared/Components/AccentColorManager.swift)
  - 支持 presets（Ocean, Forest, Sunset, Violet 等）和 Custom 调色盘。
  - 写入 `UserDefaults` 持久化，提供 `Color` 实例用于 Swift UI 渲染。

---

## 模块 6：三大核心 Tab 页面与交互 (Presentation Views)

构建符合 Design System Lite 和原生 Liquid Glass Theme 的界面。

### 6.1 今天 (Today)
- [x] 创建 [TodayViewModel.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Today/TodayViewModel.swift)
- [x] 创建 [TodayView.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Today/TodayView.swift)
  - 渲染 `timeHero` 大字号卡片（玻璃磨砂质感 + 10% Accent 染色）。
  - 显示倒计时剩余小时和分钟。
  - 权限缺失时弹出醒目的橙色警告 Card。
  - 空状态引导与一键“跳过明天”动作响应。

### 6.2 设置 (Settings)
- [x] 创建 [SettingsView.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Today/SettingsView.swift)
  - 全局 Accent 色彩选择器网格（包含自定义 HSL 范围）。
  - 权限诊断与手动同步对账调试按钮。

### 6.3 日历 (Calendar)
- [x] 创建 [CalendarViewModel.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Calendar/CalendarViewModel.swift)
- [x] 创建 [CalendarView.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Calendar/CalendarView.swift)
  - 月历 7x6 布局。
  - 日期标记：工作日（小灰字“班”）、周末（小“休”）、法定假（小红字“假”）、调休补班（小蓝字“班”）。如果当天有闹铃，显示彩色微光原点。
- [x] 创建 [DayDetailSheet.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Calendar/DayDetailSheet.swift)
  - 底部弹出单日控制中心。
  - 显示当天生效的作息与实际闹铃时间。
  - 提供：“临时休息（Skip）”、“临时工作（Force）”、“修改时间”、“恢复默认”。点击后直接保存 `Override` 并触发对账。

### 6.4 作息中心与模板编辑器 (Schedules Gallery)
- [x] 创建 [SchedulesViewModel.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Schedules/SchedulesViewModel.swift)
- [x] 创建 [SchedulesView.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Schedules/SchedulesView.swift)
  - 优雅卡片网格，展示每个作息的时间、重复规律与下一次时间。
- [x] 创建 [ScheduleEditorView.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/Features/Schedules/ScheduleEditorView.swift)
  - 整合多模板编辑器：
    - **大小周编辑组件**：定义锚点日期、A周工作日星期、B周工作日星期。
    - **轮班班制编辑组件**：可动态 Add/Delete 周期天数，配置每一天的“名称（如白班）”、“是否工作”、“是否响铃”、“自定义改时”。
    - **基本信息与铃声拾取器**。

---

## 模块 7：集成与适配测试

### 7.1 应用入口重构
- [x] 修改 [YaClockApp.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/YaClockApp.swift)
  - 组装 `AppContainer`，根据环境区分并注入 `AlarmKitScheduler` 或 `InMemoryAlarmScheduler`。
  - 设置 SwiftData 本地 Schema。
  - 改为 TabView 结构：`今天`、`日历`、`作息` 三个选项卡。

### 7.2 开发调试器维护
- [x] 修改 [SystemMonitorView.swift](file:///Users/xxz/Ios%20Project/YaClock/YaClock/SystemMonitorView.swift)
  - 仅作为底层队列的监控面板，方便在开发过程中对照真实与虚拟的系统队列数据。

### 7.3 清理老旧代码
- [x] 删除原有的 `AlarmEntity.swift`、`LocalAlarm.swift`、`AlarmListView.swift`、`AlarmEditView.swift` 等 12 个废弃的星期闹钟组件文件。
