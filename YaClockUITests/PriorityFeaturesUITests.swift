import XCTest

final class PriorityFeaturesUITests: XCTestCase {
    @MainActor
    func testHealthTemplatesVacationAndHolidayData() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["闹钟保障"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["模拟模式"].exists)
        app.buttons["休假模式"].tap()
        XCTAssertTrue(app.navigationBars["休假模式"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["暂停哪些作息"].exists)
        app.buttons["关闭"].tap()

        app.tabBars.buttons["Schedule"].tap()
        app.buttons["新建作息或选择模板"].tap()
        app.buttons["白白夜夜休休"].tap()
        XCTAssertTrue(app.navigationBars["新建作息"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["例：常规工作日"].waitForExistence(timeout: 3))
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["白白夜夜休休"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["作息操作：白白夜夜休休"].firstMatch.tap()
        app.buttons["复制作息"].tap()
        XCTAssertTrue(app.navigationBars["新建作息"].waitForExistence(timeout: 3))
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["白白夜夜休休 副本"].firstMatch.waitForExistence(timeout: 10))

        app.tabBars.buttons["Today"].tap()
        app.buttons["打开设置"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
        app.buttons["节假日数据"].tap()
        XCTAssertTrue(app.navigationBars["节假日数据"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["导入节假日更新（JSON）"].exists)
        XCTAssertTrue(app.buttons["导出数据格式示例"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "节假日数据"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    @MainActor
    func testQuickActionsAndVacationSave() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-defaultHolidayPolicy", "ignoreHoliday"]
        app.launch()
        app.tabBars.buttons["Schedule"].tap()
        app.buttons["新建作息或选择模板"].tap()
        app.buttons["白白夜夜休休"].tap()
        let name = "轮班UI-" + String(UUID().uuidString.prefix(6))
        let field = app.textFields["例：常规工作日"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + name)
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Today"].tap()
        let late = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "明天晚起 ·")).firstMatch
        for _ in 0..<4 where !late.isHittable { app.swipeUp() }
        XCTAssertTrue(late.exists)
        late.tap()
        XCTAssertTrue(app.navigationBars["明天晚起"].waitForExistence(timeout: 5))
        app.buttons["保存"].tap()
        let skip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "跳过下一次 ·")).firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(app.alerts["跳过下一次闹钟？"].waitForExistence(timeout: 5))
        app.alerts.buttons["跳过这一次"].tap()
        app.buttons["休假模式"].tap()
        XCTAssertTrue(app.navigationBars["休假模式"].waitForExistence(timeout: 5))
        let selection = app.switches[name]
        XCTAssertTrue(selection.waitForExistence(timeout: 3))
        for _ in 0..<4 where !selection.isHittable { app.swipeUp() }
        selection.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(selection.value as? String, "1")
        XCTAssertTrue(app.buttons["保存"].isEnabled)
        app.buttons["保存"].tap()
        XCTAssertTrue(app.navigationBars["休假模式"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["休假模式"].waitForExistence(timeout: 5))
        let vacation = app.buttons["休假模式"]
        for _ in 0..<4 where !vacation.isHittable { app.swipeUp() }
        vacation.tap()
        XCTAssertTrue(app.navigationBars["休假模式"].waitForExistence(timeout: 5))
        let restore = app.buttons["结束休假，恢复作息"].firstMatch
        for _ in 0..<6 where !restore.exists || !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(restore.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts["操作失败"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "休假设置"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testVacationLayoutWithLargeTextInDarkLandscape() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-themeMode", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let vacation = app.buttons["休假模式"]
        for _ in 0..<10 where !vacation.isHittable { app.swipeUp() }
        XCTAssertTrue(vacation.exists)
        vacation.tap()
        XCTAssertTrue(app.navigationBars["休假模式"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["关闭"].isHittable)
        XCTAssertFalse(app.buttons["保存"].isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "休假-深色-横屏-大字体"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
