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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalAlarm.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
