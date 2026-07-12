<!--
@Author subuhui
@Date 2026/7/12 10:17
@Description YaClock 项目的智能体规则配置文件，定义开发规范、技术栈约束及 AlarmKit 使用要点。
-->

# YaClock 项目智能体规则

你好！欢迎来到 YaClock 项目。在与 Su Huihui 配对编程时，请务必严格遵守以下项目规范和基本准则。

## 1. 基础沟通规则
- **语言偏好**：必须始终使用**中文**回答问题。
- **称呼要求**：称呼用户为 **Su Huihui**。
- **沟通风格**：保持简洁、目标导向，避免长篇大论。

## 2. 技术栈与架构约束
YaClock 是一个基于 iOS 26+ 闹钟系统（AlarmKit）的 SwiftUI 应用。

- **核心技术栈**：SwiftUI, SwiftData, AlarmKit (iOS 26+), Combine, Swift Concurrency。
- **架构模式**：采用 MVVM + Clean Architecture 三层架构：
  - **Domain 层**：纯 Swift 编写，无任何 SwiftUI/SwiftData 框架依赖。业务模型 `AlarmEntity` 需支持 `Equatable`、`Hashable` 和 `Sendable`。
  - **Data 层**：负责具体持久化和系统调度实现。使用 SwiftData 的 `@Model`（如 `LocalAlarm`），并实现与 `AlarmEntity` 的互相转换。
  - **Presentation 层**：SwiftUI 视图及 ViewModel。
- **依赖流向**：始终保持单向依赖（`Presentation -> Domain <- Data`），通过 `YaClockApp` 统一进行依赖注入。

## 3. AlarmKit 核心开发规范
- **更新闹钟（cancel → schedule 模式）**：
  `AlarmManager.schedule(id:configuration:)` 仅用于**新建**。修改已存在 ID 的闹钟时，必须先调用 `cancelAlarm(id:)`，然后调用 `scheduleAlarm(_:)`。直接调用 schedule 会导致 `Code=0` 错误。
- **模拟器降级处理**：
  在模拟器或 iOS 26 以下的实机中，AlarmKit 服务必须能够安全降级为内存模拟模式，不影响开发和测试。

## 4. 代码编写与注释规范
- **防御性编程**：不要编写过度防御性的代码。在边界（Entry Points）进行严格校验，在核心逻辑中信任数据，让程序在遇到工程 Bug 时快速崩溃（Fail Fast），禁止使用空的 `try?` 或空的 `catch` 吞掉异常（除非业务明确需要忽略）。
- **文件头部注释**：创建新文件时，必须包含以下格式的头部注释（置于文件顶部或主类定义上方）：
  ```swift
  // @Author <git config user.name>
  // @Date YYYY/M/D HH:mm
  // @Description <一句话描述文件用途>
  ```
- **属性与函数注释**：所有的属性和函数都必须有清晰的注释，解释其业务含义或设计考量（特别是为什么要这样设计），避免解释显而易见的代码。
- **最小改动原则**：只修改实现任务所必须的代码，禁止顺手重构无关代码或修改不相干的格式。

## 5. 项目资源与文档路径
- **项目文档根目录**：`/Users/xxz/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Work/workday`
- **UI交互设计规范**：`/Users/xxz/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Work/workday/02-YaClock-UX-UI-Spec-v2.0.md`
- **重构任务拆分清单**：`/Users/xxz/Ios Project/YaClock/task.md`
- **设计图目录**：`/Users/xxz/Ios Project/YaClock/screen`
