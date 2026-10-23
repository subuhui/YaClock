# YaClock

> 基于 iOS 26 AlarmKit 的系统级闹钟应用，能够穿透静音模式和专注模式响铃。

---

## P0 / P1 功能

- 首页「闹钟保障」读取真实授权和系统队列，显示下一次闹钟是否下发、成功核对范围、失败原因与重试入口；模拟器明确标记为模拟模式。
- 节假日数据支持按年份导入 JSON 更新及导出格式示例；校正内置 2026 年安排，展示来源与更新时间，缺失年份会在首页提示。
- 首页可跳过下一次闹钟、仅调整明天的响铃时间；日历中可恢复默认，重复调整同一天会覆盖旧调整。
- 休假模式支持选择日期范围和作息，含起止日，到期后继续使用原规则，可提前结束。
- 新建菜单提供双休、大小周、上二休二、白白夜夜休休模板；作息卡片菜单（或长按）可复制，确认保存前不会下发。
- 提供桌面和锁屏「下一次闹钟」小组件，中号桌面组件显示明日班次、休假及调休信息；保留贪睡实时活动。

### 数据更新格式

设置 → 节假日数据 → 导出数据格式示例。JSON 包含 `year`、`source`、ISO 8601 格式的 `updatedAt` 和 `days` 数组，每项为 `date`（yyyy-MM-dd）、`name`、`isWorkday`。导入的是整年完整数据，会替换同年份记录。应用不内置第三方在线服务；请从可信来源整理并核对后导入。

内置数据依据[国务院办公厅 2026 年节假日通知（北京市政府转载）](https://www.beijing.gov.cn/zhengce/zhengcefagui/202511/t20251104_4258873.html)。未覆盖年份暂按普通星期规则计算，并明确提示。

### 调度与小组件配置

- 调度窗口为未来 60 天，打开/返回应用时对账，另申请系统后台刷新。后台执行时间由 iOS 决定，不能承诺永久后台续排；请在已核对范围到期前打开应用。
- 两个 target 使用 App Group `group.com.subuhui.YaClock`，真机签名前需让对应开发者团队和两个 App ID 启用该组。
- 小组件快照只把系统队列核对成功的实例标为已设置；展示按时间推进，最终刷新频率受 WidgetKit 控制。
- 休假跨过当前 60 天窗口时，额外预排结束后 60 天的闹钟。休假优先于单日临时调整。每个作息保存一个休假区间，再次为该作息安排休假会替换原区间。
- 测试目标最低版本与应用一致，为 iOS 26.0。

---

## 功能特性

- **系统级闹钟** — 通过 AlarmKit 注册为系统闹钟，静音/专注模式下依然响铃
- **新建 / 编辑闹钟** — 设置时间、标签、铃声、重复日期
- **一次性 & 每周重复** — 支持按星期自由组合重复日期
- **开关切换** — 列表页直接启用/禁用，实时同步系统调度
- **系统队列监控** — 实时展示 AlarmKit 底层调度状态
- **模拟器兼容** — iOS 26 以下 / 模拟器自动切换内存模拟模式，不影响开发调试

---

## 技术栈

| 技术 | 用途 |
|---|---|
| SwiftUI | 声明式 UI |
| SwiftData | 本地持久化 |
| AlarmKit (iOS 26+) | 系统级闹钟调度 |
| Combine | AlarmKitService → Repository 状态桥接 |
| Swift Concurrency (async/await) | 异步调度与取消 |

**最低部署目标**：iOS 26.0（AlarmKit 功能），低版本自动降级为模拟模式。

---

## 架构

采用 **MVVM + Clean Architecture** 三层分层，各层单向依赖：

```
Presentation  →  Domain  ←  Data
```

### 目录结构

```
YaClock/
│
├── Domain（纯 Swift，无框架依赖）
│   ├── AlarmEntity.swift              # 值类型业务模型（Equatable / Hashable / Sendable）
│   ├── AlarmRepositoryProtocol.swift  # 持久化 + 调度的统一抽象
│   ├── SaveAlarmUseCase.swift         # 新建/编辑，封装 cancel→schedule 逻辑
│   ├── ToggleAlarmUseCase.swift       # 开关闹钟
│   └── DeleteAlarmUseCase.swift       # 删除前先取消系统调度
│
├── Data（具体实现）
│   ├── LocalAlarm.swift               # SwiftData @Model + Domain 互转扩展
│   ├── AlarmRepository.swift          # @Observable 仓储，整合 SwiftData + AlarmKit
│   ├── AlarmServiceProtocol.swift     # AlarmKit 抽象接口
│   └── AlarmKitService.swift          # AlarmKit 实现（含模拟器 fallback）
│
├── Presentation（视图层）
│   ├── AlarmListView.swift            # 闹钟列表页
│   ├── AlarmListViewModel.swift       # 列表 ViewModel
│   ├── AlarmEditView.swift            # 新建 / 编辑页
│   ├── AlarmEditViewModel.swift       # 编辑 ViewModel
│   └── SystemMonitorView.swift        # AlarmKit 系统队列监控组件
│
└── YaClockApp.swift                   # App 入口，统一构建依赖树
```

### 依赖注入流向

```
YaClockApp
  └── ModelContainer.mainContext
  └── AlarmKitService.shared
        └── AlarmRepository          (@Observable)
              ├── AlarmListView  →  AlarmListViewModel
              │     ├── ToggleAlarmUseCase
              │     └── DeleteAlarmUseCase
              └── AlarmEditView  →  AlarmEditViewModel
                    └── SaveAlarmUseCase
```

---

## AlarmKit 关键细节

### cancel → schedule 模式

`AlarmManager.schedule(id:configuration:)` 语义为**新建**，对已有 ID 直接调用会返回 `Code=0` 错误。正确的更新方式：

```swift
// SaveAlarmUseCase
try? await repository.cancelAlarm(id: entity.id)  // ID 不存在时静默忽略
try await repository.scheduleAlarm(entity)         // 始终当新建处理
```

### Info.plist 配置

AlarmKit 要求在 `Info.plist` 中声明用途描述，缺失则无法调度：

```xml
<key>NSAlarmKitUsageDescription</key>
<string>我们需要系统闹钟权限来为您创建并调度自定义闹钟。</string>
```

### 模拟器 / 低版本降级

```swift
#if targetEnvironment(simulator)
// 使用内存模拟队列，替代真实 AlarmKit 调度
#else
// 使用 AlarmKit 真实 API
#endif
```

---

## 开发环境

| 工具 | 版本 |
|---|---|
| Xcode | 26.0+ |
| Swift | 6.0+ |
| iOS Deployment Target | 26.0 |

---

## 注意事项

- AlarmKit 仅在**真机**上可用，模拟器运行时自动切换内存模拟模式
- 首次调度时系统会弹出授权弹窗，用户拒绝后所有调度请求将失败
- 重复闹钟使用 `Alarm.Schedule.Relative`（按星期），单次使用 `Recurrence.never`
