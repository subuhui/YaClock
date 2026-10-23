import Foundation
import SwiftData
import Testing
@testable import YaClock

@MainActor
@Suite(.serialized)
struct PriorityFeaturesTests {
    private func app(_ scheduler: FeatureScheduler? = nil) throws -> (AppContainer, ModelContainer) {
        let schema = Schema([LocalSchedule.self, LocalScheduleOverride.self, LocalScheduledOccurrence.self])
        let store = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (AppContainer(context: store.mainContext, scheduler: scheduler ?? FeatureScheduler()), store)
    }
    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
    }
    private func once(_ offset: Int, name: String = "测试") -> Schedule {
        Schedule(name: name, time: .init(hour: 8, minute: 0), rule: .once(.init(date: day(offset))))
    }

    @Test func vacationIncludesBothBoundaryDaysAndResumes() throws {
        var schedule = Schedule(name: "休假", time: .init(hour: 8, minute: 0),
            rule: .chineseWorkday(.init(policy: .ignoreHoliday, repeatDays: [1, 2, 3, 4, 5, 6, 7])))
        schedule.vacationStart = day(1)
        schedule.vacationEnd = day(2)
        let forced = ScheduleOverride(scheduleID: schedule.id, targetDate: day(1), action: .forceWorking)
        let occurrences = RuleEngine().generateOccurrences(for: schedule, overrides: [forced], holidays: .init(), in: day(1)...day(4))
        #expect(occurrences.count == 1)
        #expect(Calendar.current.isDate(occurrences[0].fireDate, inSameDayAs: day(3)))
        let local = try LocalSchedule.from(schedule)
        #expect(try local.toDomain() == schedule)
        schedule.vacationStart = nil
        schedule.vacationEnd = nil
        #expect(RuleEngine().generateOccurrences(for: schedule, overrides: [], holidays: .init(), in: day(1)...day(4)).count == 3)
    }

    @Test func vacationCancelsOnlySelectedScheduleAndRestores() async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        var first = once(1)
        let other = once(1, name: "保留")
        try await app.saveScheduleUseCase.execute(first)
        try await app.saveScheduleUseCase.execute(other)
        first.vacationStart = day(1); first.vacationEnd = day(1)
        try await app.saveScheduleUseCase.execute(first)
        #expect(scheduler.alarms.count == 1)
        #expect(scheduler.alarms.values.first?.scheduleID == other.id)
        first.vacationStart = nil; first.vacationEnd = nil
        try await app.saveScheduleUseCase.execute(first)
        #expect(scheduler.alarms.count == 2)
    }

    @Test func longVacationPreSchedulesResumptionBeyondRollingWindow() async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        let schedule = Schedule(name: "长假", time: .init(hour: 8, minute: 0),
            rule: .chineseWorkday(.init(policy: .ignoreHoliday, repeatDays: [1, 2, 3, 4, 5, 6, 7])),
            vacationStart: day(0), vacationEnd: day(90))
        try await app.saveScheduleUseCase.execute(schedule)
        let next = try #require(app.refreshUseCase.expected.first)
        #expect(Calendar.current.isDate(next.fireDate, inSameDayAs: day(91)))
        #expect(scheduler.alarms.count >= 60)
        #expect(app.refreshUseCase.confirmedIDs.contains(next.id))
        let home = TodayViewModel(container: app)
        home.refresh()
        #expect(home.nextOccurrence?.id == next.id)
    }

    @Test func skipChangeTimeAndRestoreReplaceSameDayOverride() async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        let schedule = once(1)
        let other = once(2)
        try await app.saveScheduleUseCase.execute(schedule)
        try await app.saveScheduleUseCase.execute(other)
        try await app.saveOverrideUseCase.execute(.init(scheduleID: schedule.id, targetDate: day(1), action: .skip))
        #expect(scheduler.alarms.count == 1)
        #expect(scheduler.alarms.values.first?.scheduleID == other.id)
        store.mainContext.insert(try LocalScheduleOverride.from(.init(scheduleID: schedule.id, targetDate: day(1), action: .skip)))
        try store.mainContext.save()
        try await app.saveOverrideUseCase.execute(.init(scheduleID: schedule.id, targetDate: day(1), action: .changeTime(.init(hour: 9, minute: 30))))
        #expect(try app.overrideRepo.fetchAll(for: schedule.id).count == 1)
        #expect(scheduler.alarms.count == 2)
        let changed = try #require(scheduler.alarms.values.first { $0.scheduleID == schedule.id })
        #expect(Calendar.current.component(.hour, from: changed.fireDate) == 9)
        #expect(Calendar.current.component(.minute, from: changed.fireDate) == 30)
        try await app.deleteOverrideUseCase.execute(on: day(1))
        #expect(try app.overrideRepo.fetchAll(for: schedule.id).isEmpty)
        #expect(Calendar.current.component(.hour, from: scheduler.alarms.values.first { $0.scheduleID == schedule.id }!.fireDate) == 8)
    }

    @Test func scheduleFailureIsVisibleAndRetryRepairsQueueAndWidget() async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        let schedule = once(1)
        scheduler.failScheduling = true
        await #expect(throws: FeatureScheduler.Failure.self) { try await app.saveScheduleUseCase.execute(schedule) }
        #expect(app.refreshUseCase.errorMessage != nil)
        #expect(app.refreshUseCase.confirmedIDs.isEmpty)
        #expect(app.refreshUseCase.scheduledThrough == nil)
        #expect(try app.scheduleRepo.fetchAll().count == 1)
        scheduler.failScheduling = false
        try await app.refreshUseCase.execute()
        #expect(app.refreshUseCase.errorMessage == nil)
        #expect(app.refreshUseCase.missingCount == 0)
        #expect(app.refreshUseCase.lastSync != nil)
        let snapshot = try #require(AlarmWidgetSnapshot.read())
        #expect(snapshot.alarms.first?.confirmed == true)
        #expect(snapshot.alarms.first?.label == schedule.name)
        #expect(snapshot.daySummaries.count == 61)
        #expect(snapshot.status.contains("模拟"))
    }

    @Test func blankEditorRetryUpdatesThePersistedDraftInsteadOfCreatingDuplicates() async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        let editor = ScheduleEditorView(schedule: nil)
        let firstAttempt = editor.makeSchedule()
        scheduler.failScheduling = true
        await #expect(throws: FeatureScheduler.Failure.self) {
            try await app.saveScheduleUseCase.execute(firstAttempt)
        }
        #expect(try app.scheduleRepo.fetchAll().count == 1)

        let retry = editor.makeSchedule()
        #expect(retry.id == firstAttempt.id)
        scheduler.failScheduling = false
        try await app.saveScheduleUseCase.execute(retry)
        let saved = try app.scheduleRepo.fetchAll()
        #expect(saved.count == 1)
        #expect(saved.first?.id == firstAttempt.id)
        #expect(Set(scheduler.alarms.values.map(\.scheduleID)) == [firstAttempt.id])
    }

    @Test(arguments: [(0, false), (0, true), (1, false), (1, true)])
    func vacationCancelsActiveAlarmOnlyWhenEffectiveToday(vacationStartsIn: Int, crossesMidnight: Bool) async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        var schedule = once(2, name: "休假作息")
        let other = once(2, name: "其他作息")
        try app.scheduleRepo.save(schedule)
        try app.scheduleRepo.save(other)
        let fireDate = crossesMidnight
            ? Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: day(-1))!
            : Date(timeIntervalSinceNow: -60)
        let active = AlarmOccurrence(id: UUID(), scheduleID: schedule.id, fireDate: fireDate,
            label: schedule.name, sound: .default, snooze: .disabled)
        let otherActive = AlarmOccurrence(id: UUID(), scheduleID: other.id, fireDate: fireDate,
            label: other.name, sound: .default, snooze: .disabled)
        for occurrence in [active, otherActive] {
            scheduler.alarms[occurrence.id] = occurrence
            scheduler.active.insert(occurrence.id)
            try app.occurrenceRepo.markScheduled(occurrence: occurrence)
        }
        try await app.refreshUseCase.execute()
        #expect(scheduler.alarms[active.id] != nil)

        schedule.vacationStart = day(vacationStartsIn)
        schedule.vacationEnd = day(vacationStartsIn)
        // 与 VacationView 相同：批量持久化后普通对账，不能依赖编辑器 rescheduling 参数。
        try app.scheduleRepo.save(schedule)
        try await app.refreshUseCase.execute()
        #expect((scheduler.alarms[active.id] != nil) == (vacationStartsIn > 0))
        #expect(scheduler.alarms[otherActive.id] != nil)
        let records = try app.occurrenceRepo.fetchAll()
        #expect(records.contains { $0.id == active.id } == (vacationStartsIn > 0))
        #expect(app.refreshUseCase.expected.contains { $0.scheduleID == schedule.id })
    }

    @Test func queueVerificationDetectsSilentSchedulingFailure() async throws {
        let scheduler = FeatureScheduler()
        scheduler.ignoreScheduling = true
        let (app, store) = try app(scheduler)
        _ = store
        await #expect(throws: (any Error).self) { try await app.saveScheduleUseCase.execute(once(1)) }
        #expect(app.refreshUseCase.errorMessage != nil)
        #expect(app.refreshUseCase.missingCount == 1)
        #expect(app.refreshUseCase.scheduledThrough == nil)
    }

    @Test func activeSnoozeSurvivesAutomaticRefresh() async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        let schedule = once(1)
        try app.scheduleRepo.save(schedule)
        let past = AlarmOccurrence(id: UUID(), scheduleID: schedule.id, fireDate: Date(timeIntervalSinceNow: -60), label: "贪睡", sound: .default, snooze: .disabled)
        scheduler.alarms[past.id] = past
        scheduler.active = [past.id]
        try app.occurrenceRepo.markScheduled(occurrence: past)
        try await app.refreshUseCase.execute()
        #expect(scheduler.alarms[past.id] != nil)
        try await app.toggleScheduleUseCase.execute(id: schedule.id)
        #expect(scheduler.alarms.isEmpty)
    }

    @Test func systemQueueRemovalInvalidatesConfirmationAndSnapshot() async throws {
        let scheduler = FeatureScheduler()
        let (app, store) = try app(scheduler)
        _ = store
        try await app.saveScheduleUseCase.execute(once(1))
        scheduler.alarms.removeAll()
        await app.refreshUseCase.verifyQueue()
        #expect(app.refreshUseCase.missingCount == 1)
        #expect(app.refreshUseCase.errorMessage != nil)
        #expect(app.refreshUseCase.scheduledThrough == nil)
        #expect(AlarmWidgetSnapshot.read()?.alarms.first?.confirmed == false)
        try await app.refreshUseCase.execute()
        #expect(app.refreshUseCase.errorMessage == nil)
    }

    @Test func deniedAuthorizationDoesNotReportSuccessfulPermissionRequest() async throws {
        let scheduler = FeatureScheduler()
        scheduler.permission = .denied
        let (app, store) = try app(scheduler)
        _ = store
        await #expect(throws: (any Error).self) { try await app.refreshUseCase.requestPermission() }
        #expect(app.refreshUseCase.lastSync == nil)
    }

    @Test func templatesAndCopiesHaveIndependentIdentityAndKeepOriginalConfiguration() {
        for template in ScheduleTemplate.allCases {
            let schedule = template.makeSchedule()
            let copy = schedule.copyForCreation()
            #expect(copy.id != schedule.id)
            #expect(copy.rule == schedule.rule)
            #expect(copy.time == schedule.time)
            #expect(copy.vacationStart == nil)
            #expect(copy.name == schedule.name + " 副本")
        }
        if case .cycle(let rule) = ScheduleTemplate.shifts.makeSchedule().rule {
            #expect(rule.cycleDays.count == 6)
            #expect(rule.cycleDays[2].timeOverride == .init(hour: 18, minute: 0))
            #expect(!rule.cycleDays[4].isRinging)
        } else { Issue.record("轮班模板类型错误") }
    }

    @Test func officialHolidayDatesAndCrossYearCoverage() {
        func date(_ month: Int, _ day: Int) -> Date {
            Calendar.current.date(from: .init(year: 2026, month: month, day: day))!
        }
        let provider = HolidayProvider()
        #expect(provider.checkHoliday(on: date(1, 2)) == .holiday(name: "元旦"))
        #expect(provider.checkHoliday(on: date(2, 14)) == .workday(reason: "春节补班"))
        #expect(provider.checkHoliday(on: date(2, 15)) == .holiday(name: "春节"))
        #expect(provider.checkHoliday(on: date(6, 19)) == .holiday(name: "端午节"))
        #expect(provider.checkHoliday(on: date(6, 14)) == nil)
        #expect(provider.checkHoliday(on: date(9, 20)) == .workday(reason: "国庆节补班"))
        #expect(provider.checkHoliday(on: date(9, 27)) == .holiday(name: "中秋节"))
        let nextYear = Calendar.current.date(from: .init(year: 2027, month: 1, day: 2))!
        #expect(HolidayProvider.missingYears(in: date(12, 20)...nextYear) == [2027])
    }

    @Test func holidayImportValidatesBeforeReplacingYearAndPersists() throws {
        let original = UserDefaults.standard.data(forKey: HolidayProvider.storageKey)
        defer { UserDefaults.standard.set(original, forKey: HolidayProvider.storageKey) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let valid = HolidayDataset(year: 2099, source: "测试来源", updatedAt: Date(), days: [.init(date: "2099-01-01", name: "测试假期", isWorkday: false)])
        try HolidayProvider.importData(encoder.encode(valid))
        #expect(HolidayProvider.datasets.contains { $0.year == 2026 })
        #expect(HolidayProvider.datasets.first { $0.year == 2099 }?.days.count == 1)
        let invalid = HolidayDataset(year: 2099, source: "来源", updatedAt: Date(), days: [.init(date: "2099-02-30", name: "无效", isWorkday: false)])
        #expect(throws: HolidayImportError.self) { try HolidayProvider.importData(encoder.encode(invalid)) }
        #expect(HolidayProvider.datasets.first { $0.year == 2099 }?.days.first?.name == "测试假期")
        let duplicate = HolidayDataset(year: 2099, source: "来源", updatedAt: Date(), days: valid.days + valid.days)
        #expect(throws: HolidayImportError.self) { try HolidayProvider.importData(encoder.encode(duplicate)) }
    }
}

@MainActor
private final class FeatureScheduler: AlarmScheduler {
    enum Failure: Error { case schedule }
    var alarms: [UUID: AlarmOccurrence] = [:]
    var active: Set<UUID> = []
    var permission: AlarmPermission = .simulated
    func requestPermission() async throws -> AlarmPermission { permission }
    var failScheduling = false
    var ignoreScheduling = false
    func schedule(_ occurrence: AlarmOccurrence) async throws {
        if failScheduling { throw Failure.schedule }
        if !ignoreScheduling { alarms[occurrence.id] = occurrence }
    }
    func cancel(id: UUID) async throws { alarms.removeValue(forKey: id) }
    func scheduledIDs() async throws -> Set<UUID> { Set(alarms.keys) }
    func activeIDs() async throws -> Set<UUID> { active }
}
