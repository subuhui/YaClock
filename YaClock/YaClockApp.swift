//
//  YaClockApp.swift
//  YaClock
//
//  Created by 张哲铭 on 2026/7/11.
//

import SwiftUI
import SwiftData

@main
struct YaClockApp: App {

    let container: ModelContainer
    let repository: AlarmRepository

    init() {
        let schema = Schema([LocalAlarm.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.container = container
            // 依赖树：ModelContainer.mainContext → AlarmRepository → Views
            self.repository = AlarmRepository(
                modelContext: container.mainContext,
                alarmService: AlarmKitService.shared
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AlarmListView(repository: repository)
        }
        .modelContainer(container)
    }
}

