# YaClock

> 基于 iOS 26 AlarmKit 的系统级闹钟应用，能够穿透静音模式和专注模式响铃。

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
