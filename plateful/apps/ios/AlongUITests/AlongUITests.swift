import XCTest

final class AlongUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            let above = element.exists && element.frame.midY < app.frame.height * 0.2
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.4 : 0.70))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.65 : 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected visible control: \(element)")
    }
    func testOnboardingCheckInJourneyAndPersistence() throws {
        app.launchArguments = ["--reset-demo"]
        app.launch()
        let begin = app.buttons["Meet your companion"]
        XCTAssertTrue(begin.waitForExistence(timeout: 12)); reveal(begin); capture("01-welcome"); begin.tap()
        let name = app.textFields["Your first name (optional)"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Alex\n")
        let next = app.buttons["Continue"]; reveal(next); next.tap()
        let start = app.buttons["Begin with Pip"]; reveal(start); start.tap()
        let checkIn = app.buttons["How’s today feeling?"]
        XCTAssertTrue(checkIn.waitForExistence(timeout: 8)); capture("02-today"); reveal(checkIn); checkIn.tap()
        app.buttons["Pretty good"].tap()
        let appetite = app.buttons["Comfortable"]; reveal(appetite); appetite.tap()
        let routine = app.buttons["Made time for food"]; reveal(routine); routine.tap()
        let save = app.buttons["Save this moment"]; reveal(save); XCTAssertTrue(save.isEnabled); save.tap()
        let back = app.buttons["Back to my day"]; XCTAssertTrue(back.waitForExistence(timeout: 5)); capture("03-moment-saved"); reveal(back); back.tap()
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.staticTexts["Your last seven days"].waitForExistence(timeout: 5)); capture("04-journey")
        app.tabBars.buttons["Pip"].tap()
        XCTAssertTrue(app.staticTexts["A little friend\nfor the everyday."].waitForExistence(timeout: 5)); capture("05-companion")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["View today’s check-in"].waitForExistence(timeout: 8), "Saved check-in must survive relaunch")
        app.buttons["View today’s check-in"].tap()
        let update = app.buttons["Update this moment"]; reveal(update); XCTAssertTrue(update.isEnabled); update.tap()
        let done = app.buttons["Back to my day"]; reveal(done); done.tap()
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.staticTexts["9"].waitForExistence(timeout: 5), "Editing must not add a duplicate recorded day")
    }
    func testBlankJournalAndMilestone() throws {
        app.launchArguments = ["--reset-demo"]
        app.launch()
        let begin = app.buttons["Meet your companion"]; XCTAssertTrue(begin.waitForExistence(timeout: 10)); reveal(begin); begin.tap()
        let next = app.buttons["Continue"]; reveal(next); next.tap()
        let blank = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Start my own journal")).firstMatch; reveal(blank); blank.tap()
        let start = app.buttons["Begin with Pip"]; reveal(start); start.tap()
        XCTAssertTrue(app.buttons["How’s today feeling?"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.staticTexts["Your story starts here"].waitForExistence(timeout: 5))
        app.buttons["Add to your journey"].tap(); app.buttons["Personal milestone"].tap()
        let title = app.textFields["e.g. Enjoyed a walk with a friend"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("A walk with Sam")
        app.swipeUp()
        let save = app.buttons["Keep this moment"]; reveal(save); save.tap()
        XCTAssertTrue(app.staticTexts["A walk with Sam"].waitForExistence(timeout: 5)); capture("06-first-milestone")
    }
    func testWeightAndDataReset() throws {
        app.launchArguments = ["--reset-demo", "--sample-journey"]
        app.launch()
        XCTAssertTrue(app.buttons["How’s today feeling?"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Journey"].tap()
        app.buttons["Add to your journey"].tap(); app.buttons["Weight record (optional)"].tap()
        let weight = app.textFields["Weight value"]; XCTAssertTrue(weight.waitForExistence(timeout: 5)); weight.tap(); weight.typeText("90.5")
        let save = app.buttons["Save weight record"]; reveal(save); XCTAssertTrue(save.isEnabled); capture("07a-weight-form"); save.tap()
        capture("07b-after-weight-save")
        XCTAssertTrue(app.navigationBars["Your journey"].waitForExistence(timeout: 8), "Saving weight should return to the journey")
        let chart = app.staticTexts["Weight, in perspective"]; reveal(chart); XCTAssertTrue(chart.exists); capture("07-weight-records")
        app.tabBars.buttons["You"].tap()
        let remove = app.buttons["Delete all local data"]; reveal(remove); remove.tap()
        let confirm = app.buttons.matching(identifier: "Delete all local data").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.buttons["Meet your companion"].waitForExistence(timeout: 8), "Deletion returns to onboarding")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["Meet your companion"].waitForExistence(timeout: 8), "Deleted records must stay deleted after restart")
    }
    func testWeeklyReflection() throws {
        app.launchArguments = ["--reset-demo", "--sample-journey"]
        app.launch()
        XCTAssertTrue(app.buttons["How’s today feeling?"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Journey"].tap()
        let reflection = app.buttons["Read your weekly reflection"]; reveal(reflection); reflection.tap()
        XCTAssertTrue(app.navigationBars["Your weekly reflection"].waitForExistence(timeout: 5))
        let moments = app.staticTexts["2 moments you kept"]; reveal(moments)
        capture("08-weekly-reflection")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Your journey"].waitForExistence(timeout: 5))
    }
}
