import XCTest

final class AlongUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    /// Every launch, including persistence checks, stays in the UI-test data directory.
    private func launchSandbox(reset: Bool = true, arguments: [String] = []) {
        app.launchArguments = ["--ui-testing"] + (reset ? ["--reset-demo"] : []) + arguments
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            let above = element.exists && element.frame.midY < app.frame.height * 0.2
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.4 : 0.70))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.65 : 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected visible control: \(element)", file: file, line: line)
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button: \(identifier)", file: file, line: line)
        reveal(button, file: file, line: line)
        XCTAssertTrue(button.isEnabled, "Disabled button: \(identifier)", file: file, line: line)
        button.tap()
    }

    private func assertOnboardingStep(_ step: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["onboarding.step.\(step)"].waitForExistence(timeout: 10),
                      "Expected onboarding screen \(step)", file: file, line: line)
        XCTAssertFalse(app.tabBars.buttons["Today"].exists, "Onboarding must not unlock the journal", file: file, line: line)
    }

    private func selectIfPresent(_ identifier: String) {
        let button = app.buttons[identifier]
        if button.exists && !button.isSelected {
            reveal(button)
            button.tap()
        }
    }

    private func fillIfEmpty(_ identifier: String, with text: String) {
        let field = app.textFields[identifier].exists ? app.textFields[identifier] : app.textViews[identifier]
        guard field.exists else { return }
        let value = field.value as? String ?? ""
        guard value.isEmpty || value == field.placeholderValue else { return }
        reveal(field)
        field.tap()
        field.typeText(text)
    }

    private func answerCurrentScreen() {
        for identifier in [
            "onboarding.stage.recent", "onboarding.priority.progress", "onboarding.obstacle.noticing",
            "onboarding.progress.energy", "onboarding.progress.confidence", "onboarding.weight.show",
            "onboarding.routine.nutrition", "onboarding.routine.movement",
            "onboarding.mood.steady", "onboarding.appetite.comfortable"
        ] {
            selectIfPresent(identifier)
        }
        fillIfEmpty("onboarding.name", with: "Alex")
        fillIfEmpty("onboarding.weight.value", with: "90.5")
        fillIfEmpty("onboarding.intention", with: "Notice the moments that matter.")
        fillIfEmpty("onboarding.companionName", with: "Pip")
        fillIfEmpty("onboarding.note", with: "I made time for a quiet walk.")
    }

    private func advanceThroughOnboarding(from first: Int = 1, through last: Int) {
        for step in first...last {
            assertOnboardingStep(step)
            if step == 4 {
                tap("onboarding.skip") // A start date is optional.
            } else {
                answerCurrentScreen()
                tap("onboarding.continue")
            }
        }
        assertOnboardingStep(last + 1)
    }

    private func launchSampleJourney() {
        launchSandbox(arguments: ["--sample-journey"])
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["How’s today feeling?"].waitForExistence(timeout: 5))
    }

    private func recordedDays() -> Int {
        let value = app.staticTexts["journey.daysRecorded"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        reveal(value)
        let count = Int(value.label)
        XCTAssertNotNil(count, "The recorded-days metric should expose its numeric value")
        return count ?? -1
    }

    func testAll26OnboardingScreensHaveReviewScreenshots() {
        for step in 1...26 {
            if step > 1 { app.terminate() }
            // Fixture steps are zero-based; the accessibility headers are one-based.
            launchSandbox(arguments: ["--onboarding-step", String(step - 1)])
            assertOnboardingStep(step)
            capture(String(format: "%02d", step))
        }
    }

    func testFullOnboardingStopsAtPaywallAndCanOpenExplicitDesignPreview() {
        launchSandbox()
        advanceThroughOnboarding(through: 25)
        XCTAssertTrue(app.buttons["onboarding.subscribe"].exists)
        XCTAssertTrue(app.buttons["onboarding.restore"].exists)
        capture("onboarding-completed-paywall")

        // The DEBUG-only route requires an explicit confirmation and is not a purchase.
        tap("onboarding.preview")
        let confirmation = app.alerts.buttons["Open design preview"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        confirmation.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 8))
        let badge = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[cd] %@", "design preview")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "Local preview must be conspicuously labelled")
        XCTAssertFalse(app.buttons["onboarding.subscribe"].exists)
        capture("explicit-local-design-preview")
    }

    func testUnconnectedPurchaseAndRestoreNeverUnlockJournal() {
        launchSandbox(arguments: ["--onboarding-step", "25"])
        assertOnboardingStep(26)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS[cd] %@", "trial")).count, 0,
                       "The membership offer must not contain a trial CTA")

        for plan in ["onboarding.plan.monthly", "onboarding.plan.annual"] {
            tap(plan)
            tap("onboarding.subscribe")
            let alert = app.alerts["Purchases aren’t connected"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertFalse(app.tabBars.buttons["Today"].exists)
            alert.buttons["OK"].tap()
            assertOnboardingStep(26)
        }

        tap("onboarding.restore")
        let restoreAlert = app.alerts.firstMatch
        XCTAssertTrue(restoreAlert.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        restoreAlert.buttons["OK"].tap()
        assertOnboardingStep(26)

        app.terminate()
        launchSandbox(reset: false)
        assertOnboardingStep(26)
        tap("onboarding.close")
        assertOnboardingStep(24)
        tap("onboarding.continue")
        assertOnboardingStep(25)
        tap("onboarding.continue")
        assertOnboardingStep(26)
    }

    func testIncompleteOnboardingResumesAtSavedStep() {
        launchSandbox()
        advanceThroughOnboarding(through: 6)
        app.terminate()
        launchSandbox(reset: false)
        assertOnboardingStep(7)
        tap("onboarding.back")
        assertOnboardingStep(6)
        tap("onboarding.continue")
        assertOnboardingStep(7)
    }

    func testSampleJourneyCheckInAndPersistence() {
        launchSampleJourney()
        app.tabBars.buttons["Journey"].tap()
        let previousCount = recordedDays()
        app.tabBars.buttons["Today"].tap()
        tap("How’s today feeling?")
        tap("Pretty good")
        tap("Comfortable")
        tap("Made time for food")
        tap("Save this moment")
        XCTAssertTrue(app.buttons["Back to my day"].waitForExistence(timeout: 5))
        capture("journal-moment-saved")
        tap("Back to my day")
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.staticTexts["Your last seven days"].waitForExistence(timeout: 5))
        XCTAssertEqual(recordedDays(), previousCount + 1)
        capture("journal-after-check-in")
        app.tabBars.buttons["Pip"].tap()
        XCTAssertTrue(app.staticTexts["A little friend\nfor the everyday."].waitForExistence(timeout: 5))
        capture("journal-companion")

        app.terminate()
        launchSandbox(reset: false)
        XCTAssertTrue(app.buttons["View today’s check-in"].waitForExistence(timeout: 8), "Saved check-in must survive relaunch")
        tap("View today’s check-in")
        tap("Update this moment")
        tap("Back to my day")
        app.tabBars.buttons["Journey"].tap()
        XCTAssertEqual(recordedDays(), previousCount + 1, "Editing must not add a duplicate recorded day")
    }

    func testBlankJournalAndMilestone() {
        launchSampleJourney()
        app.tabBars.buttons["You"].tap()
        tap("Start a blank journal")
        tap("Replace journal")
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.staticTexts["Your story starts here"].waitForExistence(timeout: 5))
        tap("Add to your journey")
        tap("Personal milestone")
        let title = app.textFields["e.g. Enjoyed a walk with a friend"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("A walk with Sam")
        tap("Keep this moment")
        XCTAssertTrue(app.staticTexts["A walk with Sam"].waitForExistence(timeout: 5))
        capture("journal-first-milestone")
    }

    func testWeightAndDataReset() {
        launchSampleJourney()
        app.tabBars.buttons["Journey"].tap()
        tap("Add to your journey")
        tap("Weight record (optional)")
        let weight = app.textFields["Weight value"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("90.5")
        capture("journal-weight-form")
        tap("Save weight record")
        XCTAssertTrue(app.navigationBars["Your journey"].waitForExistence(timeout: 8), "Saving weight should return to the journey")
        let chart = app.staticTexts["Weight, in perspective"]
        reveal(chart)
        XCTAssertTrue(chart.exists)
        capture("journal-weight-records")

        app.tabBars.buttons["You"].tap()
        tap("Delete all local data")
        let confirmation = app.sheets.buttons["Delete all local data"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        assertOnboardingStep(1)
        app.terminate()
        launchSandbox(reset: false)
        assertOnboardingStep(1)
    }

    func testWeeklyReflection() {
        launchSampleJourney()
        app.tabBars.buttons["Journey"].tap()
        tap("Read your weekly reflection")
        XCTAssertTrue(app.navigationBars["Your weekly reflection"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["2 moments you kept"])
        capture("journal-weekly-reflection")
        tap("Done")
        XCTAssertTrue(app.navigationBars["Your journey"].waitForExistence(timeout: 5))
    }
}
