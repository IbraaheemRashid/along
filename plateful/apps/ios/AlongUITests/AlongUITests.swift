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
        // Capture the composited screen, including native bars and safe areas.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, centerInScroll: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if !centerInScroll && element.exists && element.isHittable { return }
            // Keep the gesture inside visible content. At large text sizes the
            // fixed footer occupies much more of the screen; a keyboard also
            // makes screen-relative swipes miss the scroll view entirely.
            let scroll = app.scrollViews.firstMatch
            let bounds = scroll.exists ? scroll.frame.intersection(app.frame) : app.frame
            let top = max(bounds.minY + 16, app.frame.minY + 100)
            var bottom = min(bounds.maxY - 16, app.frame.maxY - 100)
            if app.keyboards.firstMatch.exists { bottom = min(bottom, app.keyboards.firstMatch.frame.minY - 12) }
            for identifier in ["onboarding.continue", "onboarding.subscribe"] {
                let action = app.buttons[identifier]
                if action.exists { bottom = min(bottom, action.frame.minY - 16) }
            }
            if centerInScroll && element.exists && element.isHittable && element.frame.midY > top && element.frame.midY < bottom { return }
            let height = max(80, bottom - top)
            let above = element.exists && element.frame.midY < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.width * 0.5, dy: top + height * (above ? 0.25 : 0.85)))
            let end = origin.withOffset(CGVector(dx: app.frame.width * 0.5, dy: top + height * (above ? 0.85 : 0.25)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        if centerInScroll { XCTFail("Expected control centre inside scrollable content: \(element)", file: file, line: line); return }
        XCTAssertTrue(element.exists && element.isHittable, "Expected visible control: \(element)", file: file, line: line)
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[identifier]
        // A lazy Form may not mount an offscreen row until it scrolls into view.
        // Waiting for existence before scrolling would fail on a valid control.
        reveal(button, file: file, line: line)
        XCTAssertTrue(button.exists, "Missing button after scrolling: \(identifier)", file: file, line: line)
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
            if step == 20 { capture("20") }
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

    func testCompanionDesignReview() {
        for (name, arguments) in [("light", [String]()), ("dark", ["--dark-review"]), ("large", ["--dark-review", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])] {
            launchSandbox(arguments: ["--sample-journey"] + arguments)
            XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
            capture("today-\(name)")
            tap("How’s today feeling?")
            reveal(app.buttons["Save this moment"])
            app.buttons["Close"].tap()
            app.tabBars.buttons["Pip"].tap()
            capture("pip-\(name)")
            tap("companion.accessory.scarf")
            XCTAssertTrue(app.buttons["companion.accessory.scarf"].isSelected)
            app.terminate()
        }
    }

    func testRoomOpensCompanionAndKeepsakePersists() {
        launchSampleJourney()
        tap("today.companion")
        XCTAssertTrue(app.tabBars.buttons["Pip"].isSelected)
        tap("companion.accessory.scarf")
        XCTAssertTrue(app.buttons["companion.accessory.scarf"].isSelected)
        app.terminate()
        launchSandbox(reset: false)
        tap("today.companion")
        let scarf = app.buttons["companion.accessory.scarf"]
        reveal(scarf)
        XCTAssertTrue(scarf.isSelected, "Chosen keepsake must survive restarting the app")
        capture("pip-selected-scarf")
    }

    func testPipPettingStoriesAndDiscoveryPersistence() {
        launchSampleJourney()
        tap("pet.greet")
        XCTAssertEqual(app.buttons["pet.greet"].value as? String, "Hello, little friend.")
        capture("pip-petting")
        tap("today.companion")
        tap("pet.story.open")
        capture("pip-story-question")
        tap("pet.story.rain")
        XCTAssertTrue(app.staticTexts["Rainy-day rhythms"].waitForExistence(timeout: 5))
        capture("pip-story-discovery")
        tap("Back to Pip")
        let discovery = app.buttons["pet.discovery.window"]
        reveal(discovery)
        XCTAssertTrue(discovery.exists)
        app.terminate()
        launchSandbox(reset: false)
        app.tabBars.buttons["Pip"].tap()
        reveal(app.buttons["pet.discovery.window"])
        XCTAssertTrue(app.buttons["pet.discovery.window"].exists)
    }

    func testWholeAppStyleReview() {
        launchSampleJourney()
        capture("style-today")
        for tab in ["Journey", "Pip", "You"] {
            app.tabBars.buttons[tab].tap()
            capture("style-\(tab.lowercased())")
        }
        tap("Privacy & your journal")
        capture("style-privacy")
        tap("Done")
        tap("Explore Along Plus — preview")
        capture("style-membership")
        tap("Terms")
        capture("style-terms")
    }

    func testDevLabSetupShortcuts() {
        launchSandbox()
        tap("dev.open")
        XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
        capture("dev-lab-menu")
        for (scenario, step) in [("fresh", 1), ("resume", 14), ("paywall", 26)] {
            tap("dev.scenario.\(scenario)")
            assertOnboardingStep(step)
            XCTAssertTrue(app.staticTexts["dev.sandbox.banner"].exists)
            capture("dev-setup-\(scenario)")
            tap("dev.sandbox.close")
        }
        tap("dev.close")
        assertOnboardingStep(1)
    }

    func testDevLabScenariosDoNotChangeOriginalOnboarding() {
        launchSandbox()
        assertOnboardingStep(1)

        let scenarios: [(name: String, days: Int?)] = [
            ("empty", nil), ("sample", 8), ("sparse", 2), ("month", 30)
        ]
        for scenario in scenarios {
            tap("dev.open")
            XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
            tap("dev.scenario.\(scenario.name)")
            let banner = app.descendants(matching: .any).matching(identifier: "dev.sandbox.banner").firstMatch
            XCTAssertTrue(banner.waitForExistence(timeout: 5), "Scenario must be visibly identified as a sandbox")
            XCTAssertTrue(app.tabBars.buttons["Journey"].waitForExistence(timeout: 5))
            app.tabBars.buttons["Journey"].tap()
            if let days = scenario.days {
                XCTAssertEqual(recordedDays(), days, "Unexpected fixture for \(scenario.name)")
            } else {
                reveal(app.staticTexts["Your story starts here"])
            }
            capture("dev-scenario-\(scenario.name)")

            tap("dev.sandbox.close")
            XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
            tap("dev.close")
            assertOnboardingStep(1)
        }

        app.terminate()
        launchSandbox(reset: false)
        assertOnboardingStep(1)
    }

    func testDevLabOnboardingCatalogueLeavesOriginalJourneyUntouched() {
        launchSandbox(arguments: ["--onboarding-step", "0"])
        assertOnboardingStep(1)
        tap("dev.open")
        XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
        tap("dev.onboarding")
        XCTAssertTrue(app.navigationBars["Design review"].waitForExistence(timeout: 5))
        tap("dev.onboarding.26")
        assertOnboardingStep(26)
        XCTAssertTrue(app.buttons["onboarding.subscribe"].exists)
        capture("dev-onboarding-catalogue-paywall")

        tap("dev.onboarding.close")
        let catalogue = app.navigationBars["Design review"]
        XCTAssertTrue(catalogue.waitForExistence(timeout: 5))
        tap("dev.onboarding.catalogue.close")
        XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
        tap("dev.close")
        assertOnboardingStep(1)
    }

    func testDevLabFeatureShortcutAndSavedSessionSurviveRestart() {
        launchSandbox()
        tap("dev.open")
        tap("dev.feature.checkIn")
        tap("Pretty good")
        tap("Comfortable")
        tap("Save this moment")
        tap("Back to my day")
        app.tabBars.buttons["Journey"].tap()
        XCTAssertEqual(recordedDays(), 9, "The shortcut must save into its sample sandbox")
        tap("dev.sandbox.controls")
        tap("dev.reloadSaved")
        XCTAssertEqual(recordedDays(), 9, "Reloading from disk must preserve the new entry")
        tap("dev.sandbox.close")
        tap("dev.close")
        assertOnboardingStep(1)

        app.terminate()
        launchSandbox(reset: false)
        assertOnboardingStep(1)
        tap("dev.open")
        tap("dev.resumeLast")
        app.tabBars.buttons["Journey"].tap()
        XCTAssertEqual(recordedDays(), 9, "Resume must reopen saved edits rather than regenerate the fixture")
        capture("dev-resumed-sandbox")
        tap("dev.sandbox.close")
        tap("dev.close")
        assertOnboardingStep(1)
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

    func testCheckInAndPaywallSupportDarkModeAndLargestAccessibilityText() {
        for step in [21, 26] {
            if step == 26 { app.terminate() }
            launchSandbox(arguments: [
                "--onboarding-step", String(step - 1),
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "--dark-review"
            ])
            assertOnboardingStep(step)
            capture(String(format: "%02d-dark-xxxl-top", step))

            if step == 26 {
                for plan in ["annual", "monthly"] {
                    let control = app.buttons["onboarding.plan.\(plan)"]
                    reveal(control, centerInScroll: true)
                    XCTAssertTrue(control.isEnabled, "The \(plan) price control must remain usable with large text")
                    control.tap()
                    XCTAssertTrue(control.isSelected, "The \(plan) must be selectable with large text")
                    capture("26-dark-xxxl-\(plan)-price")
                }
            }

            let cta = app.buttons[step == 26 ? "onboarding.subscribe" : "onboarding.continue"]
            reveal(cta)
            XCTAssertTrue(cta.isEnabled, "The primary action must remain usable with large text")
            capture(String(format: "%02d-dark-xxxl-primary-action", step))
            XCTAssertFalse(app.tabBars.buttons["Today"].exists, "Review fixtures must remain outside the personal journal")
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
        let title = app.textFields["milestone.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("A walk with Sam")
        XCTAssertEqual(title.value as? String, "A walk with Sam")
        if app.buttons["milestone.keyboardDone"].exists { tap("milestone.keyboardDone") }
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
