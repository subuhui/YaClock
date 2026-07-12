// @Author subuhui
// @Date 2026/7/12 11:28
// @Description 应用主入口，初始化 SwiftData 容器与 AppContainer 依赖树，渲染三 Tab 主界面

import SwiftUI
import SwiftData

@main
struct YaClockApp: App {

    /// SwiftData 模型容器
    let modelContainer: ModelContainer

    /// 统一依赖容器，注入到整个视图树
    let appContainer: AppContainer

    init() {
        let schema = Schema([
            LocalSchedule.self,
            LocalScheduleOverride.self,
            LocalScheduledOccurrence.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let mc = try ModelContainer(for: schema, configurations: [config])
            self.modelContainer = mc

            // 根据运行环境选择调度器：真机使用 AlarmKit，其余降级为内存模拟
            let scheduler: AlarmScheduler
            #if targetEnvironment(simulator)
            scheduler = InMemoryAlarmScheduler()
            #else
            if #available(iOS 26.0, *) {
                scheduler = AlarmKitScheduler()
            } else {
                scheduler = InMemoryAlarmScheduler()
            }
            #endif

            self.appContainer = AppContainer(context: mc.mainContext, scheduler: scheduler)
        } catch {
            fatalError("SwiftData ModelContainer 初始化失败：\(error)")
        }
    }

    @AppStorage("themeMode") private var themeMode = "system"

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(themeMode == "light" ? .light : (themeMode == "dark" ? .dark : nil))
                .environment(appContainer)
                .modelContainer(modelContainer)
        }
    }
}

// MARK: - 三 Tab 主界面

struct MainTabView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView(container: container)
            }

            Tab("Calendar", systemImage: "calendar") {
                CalendarView(container: container)
            }

            Tab("Schedule", systemImage: "list.bullet.rectangle") {
                SchedulesView(container: container)
            }
        }
    }
}
