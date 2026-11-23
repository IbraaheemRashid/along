import XCTest
import UIKit

final class AlongUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            capture("failure-\(name)")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Failure hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        }
        app.terminate()
        app = nil
    }

    private func navigationTab(_ title: String) -> XCUIElement {
        if UIDevice.current.userInterfaceIdiom != .pad { return app.tabBars.buttons[title] }
        // iPadOS presents the system tabs as top-bar buttons, not a TabBar.
        let icons = ["Today": "house.fill", "Health": "heart.text.square.fill", "Progress": "chart.bar.xaxis", "Settings": "gearshape"]
        return app.buttons.matching(identifier: icons[title] ?? title).matching(NSPredicate(format: "label == %@", title)).firstMatch
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
            let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? app.scrollViews.firstMatch
            let bounds = scroll.exists ? scroll.frame.intersection(app.frame) : app.frame
            let top = max(bounds.minY + 16, app.frame.minY + 100)
            var bottom = min(bounds.maxY - 16, app.frame.maxY - 100)
            if app.keyboards.firstMatch.exists { bottom = min(bottom, app.keyboards.firstMatch.frame.minY - 12) }
            for identifier in ["setup.continue", "setup.subscribe"] {
                let action = app.buttons[identifier]
                if action.exists && action.isHittable { bottom = min(bottom, action.frame.minY - 16) }
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

    private func assertSetupStep(_ step: String, file: StaticString = #filePath, line: UInt = #line) {
        let screen = app.descendants(matching: .any).matching(identifier: "setup.screen.\(step)").firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Expected setup screen \(step)", file: file, line: line)
        XCTAssertFalse(navigationTab("Today").exists, "Setup must not unlock the app", file: file, line: line)
    }

    private func selectIfPresent(_ identifier: String) {
        let button = app.buttons[identifier]
        if button.exists && !button.isSelected {
            reveal(button, centerInScroll: true)
            button.tap()
        }
    }

    /// Answers whatever the current screen asks, then continues. Wheels, rulers
    /// and the date picker keep their valid defaults.
    private func answerAndContinue(_ step: String) {
        switch step {
        case "experience": selectIfPresent("setup.experience.planning")
        case "goals": selectIfPresent("setup.goal.weightLoss"); selectIfPresent("setup.goal.recovery")
        case "source": selectIfPresent("setup.source.tiktok")
        case "compounds": selectIfPresent("setup.compound.BPC-157")
        case "frequency": selectIfPresent("setup.frequency.fewPerWeek")
        case "obstacles": selectIfPresent("setup.obstacle.forgetting")
        default: break
        }
        if step == "reminders" { tap("setup.reminders.skip") } else { tap("setup.continue") }
    }

    private let setupOrder = ["welcome", "experience", "goals", "source", "showcase", "birthday", "weight", "target",
                              "commitment", "compounds", "frequency", "doseTime", "obstacles", "trust", "reminders", "referral", "ready"]

    /// Walks the real flow from welcome through the loader and plan reveal.
    private func advanceThroughSetup(until last: String = "paywall") {
        for step in setupOrder {
            if step == last { assertSetupStep(step); return }
            assertSetupStep(step)
            if step == "goals" || step == "plan" { capture("setup-\(step)") }
            answerAndContinue(step)
        }
        guard last != "ready" else { return }
        XCTAssertTrue(app.descendants(matching: .any)["setup.screen.building"].waitForExistence(timeout: 5))
        assertSetupStep("plan")
        if last == "plan" { return }
        capture("setup-plan")
        tap("setup.continue")
        assertSetupStep("paywall")
    }

    private func launchSampleJourney() {
        launchSandbox(arguments: ["--sample-journey"])
        XCTAssertTrue(navigationTab("Today").waitForExistence(timeout: 10))
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 5))
    }

    private func recordedDays() -> Int {
        let value = app.staticTexts["journey.daysRecorded"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        reveal(value)
        let count = Int(value.label)
        XCTAssertNotNil(count, "The recorded-days metric should expose its numeric value")
        return count ?? -1
    }

    func testCompanionDesignReview() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        for (name, arguments) in [("light", [String]()), ("dark", ["--dark-review"]), ("large", ["--dark-review", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])] {
            launchSandbox(arguments: ["--sample-journey", "--pip-preview-days", "7"] + arguments)
            XCTAssertTrue(navigationTab("Today").waitForExistence(timeout: 5))
            capture("today-\(name)")
            tap("How’s today feeling?")
            reveal(app.buttons["Save this moment"])
            app.buttons["Close"].tap()
            navigationTab("Pip").tap()
            capture("pip-\(name)")
            tap("companion.accessory.scarf")
            XCTAssertTrue(app.buttons["companion.accessory.scarf"].isSelected)
            app.terminate()
        }
    }

    func testRoomOpensCompanionAndKeepsakePersists() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSandbox(arguments: ["--sample-journey", "--pip-preview-days", "3"])
        XCTAssertTrue(navigationTab("Today").waitForExistence(timeout: 10))
        tap("today.companion")
        XCTAssertTrue(navigationTab("Pip").isSelected)
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

    func testPipPettingStoriesAndDiscoveryPersistence() throws {
        throw XCTSkip("Retired with the Pip journal UI")

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
        navigationTab("Pip").tap()
        reveal(app.buttons["pet.discovery.window"])
        XCTAssertTrue(app.buttons["pet.discovery.window"].exists)
    }

    func testRealRoutineEarnsKeepsakeAndPersistsWithoutFakeCheckIn() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        tap("today.companion")
        XCTAssertEqual(app.staticTexts["pet.progress.count"].label, "0 recorded days", "Samples cannot earn progress")
        tap("companion.accessory.scarf")
        XCTAssertFalse(app.buttons["companion.accessory.scarf"].isSelected, "Locked keepsakes only preview")
        navigationTab("Today").tap()
        tap("today.routine.movement")
        XCTAssertTrue(app.buttons["today.routine.movement"].label.contains("recorded today"))
        XCTAssertTrue(app.buttons["today.checkIn"].label.contains("How’s today feeling?"), "Routine logging cannot invent a check-in")
        tap("pet.reward.ready")
        capture("release-first-keepsake")
        tap("pet.reward.claim")
        XCTAssertTrue(app.staticTexts["At home in your room"].waitForExistence(timeout: 5))
        tap("Back to my day")
        tap("today.routine.movement")
        app.terminate()
        launchSandbox(reset: false)
        tap("today.companion")
        XCTAssertEqual(app.staticTexts["pet.progress.count"].label, "1 recorded day")
        reveal(app.buttons["pet.room.notebook"])
        XCTAssertTrue(app.buttons["pet.room.notebook"].label.contains("In your room"))
        capture("release-earned-notebook")
    }

    func testRoutineHistoryCanBeEditedAndFound() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        tap("today.routine.movement")
        navigationTab("Journey").tap()
        let search = app.textFields["journey.search"]
        reveal(search, centerInScroll: true); search.tap(); search.typeText("Moved\n")
        app.swipeUp()
        tap("journey.routineRecord")
        XCTAssertTrue(app.navigationBars["Your routines"].waitForExistence(timeout: 5))
        capture("release-routine-record")
        tap("Moved in my own way")
        tap("Update routines")
        navigationTab("Pip").tap()
        XCTAssertEqual(app.staticTexts["pet.progress.count"].label, "1 recorded day", "Editing routine history preserves cumulative progress")
    }

    func testBackupAndReminderScreensAreAvailableInPreview() {
        launchSampleJourney()
        navigationTab("Settings").tap()
        reveal(app.staticTexts["reminders.status"])
        XCTAssertTrue(app.staticTexts["reminders.status"].label.contains("disabled"))
        XCTAssertFalse(app.buttons["reminders.save"].isEnabled, "Preview must never schedule real notifications")
        capture("release-reminder-controls")
        tap("Backup & restore")
        XCTAssertTrue(app.navigationBars["Backup & restore"].waitForExistence(timeout: 5))
        reveal(app.buttons["backup.export"])
        capture("release-backup-controls")
        XCTAssertTrue(app.buttons["backup.export"].isEnabled)
        tap("Done")
        XCTAssertTrue(navigationTab("Settings").isSelected)
    }

    func testDevLabCanPreviewEarnedRoomAndStories() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSandbox()
        tap("dev.open")
        tap("dev.scenario.allKeepsakes")
        XCTAssertTrue(navigationTab("Pip").waitForExistence(timeout: 5))
        navigationTab("Pip").tap()
        XCTAssertEqual(app.staticTexts["pet.progress.count"].label, "60 recorded days")
        for item in ["notebook", "plant", "lantern", "stars"] {
            tap("pet.room.\(item)")
            tap("pet.reward.claim")
            tap("Back to my day")
        }
        for _ in 0..<5 { app.swipeDown() }
        capture("release-pip-room-complete")
        tap("pet.story.open")
        XCTAssertTrue(app.buttons["pet.story.rain"].waitForExistence(timeout: 5))
    }

    func testUnpaidDataControlsRemainAvailable() {
        launchSandbox(arguments: ["--setup-step", "paywall"])
        assertSetupStep("paywall")
        tap("setup.local-data")
        XCTAssertTrue(app.navigationBars["Your data & reminders"].waitForExistence(timeout: 5))
        capture("release-unpaid-data-controls")
        tap("Backup & restore")
        XCTAssertTrue(app.navigationBars["Backup & restore"].waitForExistence(timeout: 5))
        app.navigationBars["Backup & restore"].buttons["Done"].tap()
        tap("Delete all local data")
        let confirm = app.sheets.buttons["Delete all local data"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        assertSetupStep("welcome")
    }

    func testEditingPoundsDoesNotConvertTwice() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        navigationTab("Settings").tap()
        let showWeight = app.switches["settings.showWeight"]
        reveal(showWeight, centerInScroll: true)
        if showWeight.value as? String == "0" { showWeight.tap() }
        tap("lb")
        navigationTab("Journey").tap()
        let search = app.textFields["journey.search"]
        reveal(search, centerInScroll: true); search.tap(); search.typeText("Weight\n")
        let record = app.buttons.matching(identifier: "journey.weightRecord").firstMatch
        reveal(record, centerInScroll: true); record.tap()
        let value = app.textFields["Weight value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.value as? String, "206.8", "93.8 kg should initialize once as pounds")
        capture("release-edit-weight-pounds")
        tap("Save weight record")
        reveal(record, centerInScroll: true); record.tap()
        XCTAssertEqual(app.textFields["Weight value"].value as? String, "206.8", "Saving an untouched converted value must preserve the original measurement")
    }

    func testWholeAppStyleReview() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        capture("style-today")
        for tab in ["Health", "Progress", "Settings"] {
            navigationTab(tab).tap()
            capture("style-\(tab.lowercased())")
        }
        tap("Privacy & your journal")
        capture("style-privacy")
        tap("Done")
        tap("Membership & purchases")
        capture("style-membership")
        tap("Terms")
        capture("style-terms")
    }

    func testDevLabSetupShortcuts() {
        launchSandbox()
        assertSetupStep("welcome")
        tap("dev.open")
        XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
        capture("dev-lab-menu")
        for (scenario, step) in [("fresh", "welcome"), ("resume", "compounds"), ("paywall", "paywall")] {
            tap("dev.scenario.\(scenario)")
            assertSetupStep(step)
            XCTAssertTrue(app.staticTexts["dev.sandbox.banner"].exists)
            capture("dev-setup-\(scenario)")
            tap("dev.sandbox.close")
        }
        tap("dev.close")
        assertSetupStep("welcome")
    }

    func testDevLabScenariosDoNotChangeOriginalOnboarding() {
        launchSandbox()
        assertSetupStep("welcome")

        let scenarios: [(name: String, days: Int?)] = [
            ("empty", nil), ("sample", 8), ("sparse", 2), ("month", 30)
        ]
        for scenario in scenarios {
            tap("dev.open")
            XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
            tap("dev.scenario.\(scenario.name)")
            let banner = app.descendants(matching: .any).matching(identifier: "dev.sandbox.banner").firstMatch
            XCTAssertTrue(banner.waitForExistence(timeout: 5), "Scenario must be visibly identified as a sandbox")
            XCTAssertTrue(navigationTab("Journey").waitForExistence(timeout: 5))
            navigationTab("Journey").tap()
            if let days = scenario.days {
                XCTAssertEqual(recordedDays(), days, "Unexpected fixture for \(scenario.name)")
            } else {
                reveal(app.staticTexts["Your story starts here"])
            }
            capture("dev-scenario-\(scenario.name)")

            tap("dev.sandbox.close")
            XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
            tap("dev.close")
            assertSetupStep("welcome")
        }

        app.terminate()
        launchSandbox(reset: false)
        assertSetupStep("welcome")
    }

    func testDevLabOnboardingCatalogueLeavesOriginalJourneyUntouched() {
        launchSandbox()
        assertSetupStep("welcome")
        tap("dev.open")
        XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
        tap("dev.onboarding")
        XCTAssertTrue(app.navigationBars["Design review"].waitForExistence(timeout: 5))
        tap("dev.onboarding.paywall")
        assertSetupStep("paywall")
        XCTAssertTrue(app.buttons["setup.subscribe"].exists)
        capture("dev-onboarding-catalogue-paywall")

        tap("dev.onboarding.close")
        let catalogue = app.navigationBars["Design review"]
        XCTAssertTrue(catalogue.waitForExistence(timeout: 5))
        tap("dev.onboarding.catalogue.close")
        XCTAssertTrue(app.navigationBars["Dev Lab"].waitForExistence(timeout: 5))
        tap("dev.close")
        assertSetupStep("welcome")
    }

    func testDevLabFeatureShortcutAndSavedSessionSurviveRestart() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSandbox()
        tap("dev.open")
        tap("dev.feature.tab0")
        tap("Pretty good")
        XCTAssertTrue(app.buttons["Pretty good"].isSelected)
        tap("Comfortable")
        XCTAssertTrue(app.buttons["Comfortable"].isSelected)
        capture("dev-check-in-answered")
        reveal(app.buttons["Save this moment"], centerInScroll: true)
        tap("Save this moment")
        capture("dev-check-in-after-save")
        tap("Back to my day")
        navigationTab("Journey").tap()
        XCTAssertEqual(recordedDays(), 9, "The shortcut must save into its sample sandbox")
        tap("dev.sandbox.controls")
        tap("dev.reloadSaved")
        XCTAssertEqual(recordedDays(), 9, "Reloading from disk must preserve the new entry")
        tap("dev.sandbox.close")
        tap("dev.close")
        assertSetupStep("welcome")

        app.terminate()
        launchSandbox(reset: false)
        assertSetupStep("welcome")
        tap("dev.open")
        tap("dev.resumeLast")
        navigationTab("Journey").tap()
        XCTAssertEqual(recordedDays(), 9, "Resume must reopen saved edits rather than regenerate the fixture")
        capture("dev-resumed-sandbox")
        tap("dev.sandbox.close")
        tap("dev.close")
        assertSetupStep("welcome")
    }

    func testEverySetupScreenHasReviewScreenshots() {
        for (index, step) in (setupOrder + ["plan", "paywall"]).enumerated() {
            if index > 0 { app.terminate() }
            launchSandbox(arguments: ["--setup-step", step])
            assertSetupStep(step)
            capture(String(format: "setup-%02d-%@", index + 1, step))
        }
    }

    func testSetupSupportsDarkModeAndLargestAccessibilityText() {
        for (index, step) in ["goals", "compounds", "paywall"].enumerated() {
            if index > 0 { app.terminate() }
            launchSandbox(arguments: [
                "--setup-step", step,
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "--dark-review"
            ])
            assertSetupStep(step)
            capture("setup-\(step)-dark-xxxl-top")

            if step == "paywall" {
                for plan in ["annual", "monthly"] {
                    let control = app.buttons["setup.plan.\(plan)"]
                    reveal(control, centerInScroll: true)
                    control.tap()
                    XCTAssertTrue(control.isSelected, "The \(plan) plan must be selectable with large text")
                    capture("setup-paywall-dark-xxxl-\(plan)")
                }
            }

            let cta = app.buttons[step == "paywall" ? "setup.subscribe" : "setup.continue"]
            XCTAssertTrue(cta.exists && cta.isHittable, "The primary action stays pinned on screen at every text size")
            if step == "paywall" { XCTAssertFalse(cta.isEnabled, "Unconfigured purchases must stay disabled at every text size") }
            else { XCTAssertTrue(cta.isEnabled, "The primary action must remain usable with large text") }
            XCTAssertFalse(navigationTab("Today").exists, "Review fixtures must remain outside the app")
        }
    }

    func testFullSetupStopsAtPaywallAndCanOpenExplicitDesignPreview() {
        launchSandbox()
        advanceThroughSetup()
        XCTAssertTrue(app.buttons["setup.subscribe"].exists)
        XCTAssertTrue(app.buttons["setup.restore"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS[cd] %@", "trial")).count, 0,
                       "The paywall must not contain a trial CTA")
        capture("setup-completed-paywall")

        // The DEBUG-only route requires an explicit confirmation and is not a purchase.
        tap("setup.preview")
        let confirmation = app.alerts.buttons["Open design preview"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertFalse(navigationTab("Today").exists)
        confirmation.tap()
        XCTAssertTrue(navigationTab("Today").waitForExistence(timeout: 8))
        let badge = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[cd] %@", "design preview")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "Local preview must be conspicuously labelled")
        XCTAssertFalse(app.buttons["setup.subscribe"].exists)
        capture("explicit-local-design-preview")
    }

    func testSetupWithoutWeightGoalSkipsWeightScreens() {
        launchSandbox()
        for step in ["welcome", "experience"] { assertSetupStep(step); answerAndContinue(step) }
        assertSetupStep("goals")
        selectIfPresent("setup.goal.skin")
        tap("setup.continue")
        for step in ["source", "showcase", "birthday"] { assertSetupStep(step); answerAndContinue(step) }
        assertSetupStep("commitment")
        tap("setup.back")
        assertSetupStep("birthday")
    }

    func testUnconnectedPurchaseAndRestoreNeverUnlockApp() {
        launchSandbox(arguments: ["--setup-step", "paywall"])
        assertSetupStep("paywall")

        for plan in ["setup.plan.monthly", "setup.plan.annual"] {
            tap(plan)
            XCTAssertTrue(app.buttons[plan].isSelected)
            XCTAssertFalse(app.buttons["setup.subscribe"].isEnabled, "No configured products means no checkout")
            XCTAssertFalse(navigationTab("Today").exists)
        }

        tap("setup.restore")
        XCTAssertTrue(app.staticTexts["setup.billing-notice"].waitForExistence(timeout: 5))
        XCTAssertFalse(navigationTab("Today").exists)
        assertSetupStep("paywall")

        app.terminate()
        launchSandbox(reset: false)
        assertSetupStep("paywall")
        tap("setup.back")
        assertSetupStep("plan")
        XCTAssertFalse(app.buttons["setup.back"].exists, "The plan reveal never steps back into the loader")
        tap("setup.continue")
        assertSetupStep("paywall")
    }

    func testWelcomeSignInSheetExplainsAccountsAndOffersRestore() {
        launchSandbox()
        assertSetupStep("welcome")
        tap("setup.sign-in")
        XCTAssertTrue(app.buttons["setup.sign-in.apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setup.sign-in.google"].exists && app.buttons["setup.sign-in.email"].exists)
        capture("setup-sign-in")
        tap("setup.sign-in.apple")
        XCTAssertTrue(app.staticTexts["setup.sign-in.notice"].waitForExistence(timeout: 5), "Unconnected sign-in explains itself instead of failing silently")
        XCTAssertFalse(navigationTab("Today").exists)
        capture("setup-sign-in-notice")
        tap("setup.restore-backup")
        XCTAssertTrue(app.navigationBars["Backup & restore"].waitForExistence(timeout: 5))
        app.navigationBars["Backup & restore"].buttons["Done"].tap()
        assertSetupStep("welcome")
    }

    func testPeptideSearchAddsLibraryAndCustomPeptides() {
        launchSandbox(arguments: ["--setup-step", "compounds"])
        assertSetupStep("compounds")
        let search = app.textFields["setup.compounds.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("tesa")
        tap("setup.compound.Tesamorelin")
        XCTAssertTrue(app.buttons["setup.compound.Tesamorelin"].waitForExistence(timeout: 5) && app.buttons["setup.compound.Tesamorelin"].isSelected,
                      "A searched peptide joins the selection")
        search.tap()
        search.typeText("My blend")
        tap("peptide.request")
        XCTAssertEqual(element("peptide.request.status").label, "Request saved on this device.")
        XCTAssertFalse(app.buttons["peptide.request"].isEnabled)
        tap("setup.compounds.add")
        let custom = app.buttons["setup.compound.My blend"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5) && custom.isSelected, "A custom peptide can be added from search")
        capture("setup-compounds-custom")
        tap("setup.continue")
        assertSetupStep("frequency")
    }

    func testIncompleteSetupResumesAtSavedStep() {
        launchSandbox()
        advanceThroughSetup(until: "birthday")
        app.terminate()
        launchSandbox(reset: false)
        assertSetupStep("birthday")
        tap("setup.back")
        assertSetupStep("showcase")
        tap("setup.back")
        assertSetupStep("source")
        XCTAssertTrue(app.buttons["setup.source.tiktok"].isSelected, "Answers survive a relaunch")
        tap("setup.continue")
        assertSetupStep("showcase")
    }

    func testSampleJourneyCheckInAndPersistence() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        navigationTab("Journey").tap()
        let previousCount = recordedDays()
        navigationTab("Today").tap()
        tap("How’s today feeling?")
        tap("Pretty good")
        tap("Comfortable")
        tap("Made time for food")
        tap("Save this moment")
        XCTAssertTrue(app.buttons["Back to my day"].waitForExistence(timeout: 5))
        capture("journal-moment-saved")
        tap("Back to my day")
        navigationTab("Journey").tap()
        XCTAssertTrue(app.staticTexts["Your last seven days"].waitForExistence(timeout: 5))
        XCTAssertEqual(recordedDays(), previousCount + 1)
        capture("journal-after-check-in")
        navigationTab("Pip").tap()
        XCTAssertTrue(app.staticTexts["A little friend\nfor the everyday."].waitForExistence(timeout: 5))
        capture("journal-companion")

        app.terminate()
        launchSandbox(reset: false)
        XCTAssertTrue(app.buttons["View today’s check-in"].waitForExistence(timeout: 8), "Saved check-in must survive relaunch")
        tap("View today’s check-in")
        tap("Update this moment")
        tap("Back to my day")
        navigationTab("Journey").tap()
        XCTAssertEqual(recordedDays(), previousCount + 1, "Editing must not add a duplicate recorded day")
    }

    func testBlankJournalAndMilestone() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        navigationTab("Settings").tap()
        tap("Start a blank journal")
        tap("Replace journal")
        navigationTab("Journey").tap()
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
        reveal(app.staticTexts["A walk with Sam"])
        XCTAssertTrue(app.staticTexts["A walk with Sam"].exists)
        capture("journal-first-milestone")
    }

    func testWeightAndDataReset() {
        launchSampleJourney()
        navigationTab("Journey").tap()
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

        navigationTab("Settings").tap()
        tap("Delete all local data")
        let confirmation = app.sheets.buttons["Delete all local data"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        assertSetupStep("welcome")
        app.terminate()
        launchSandbox(reset: false)
        assertSetupStep("welcome")
    }

    func testWeeklyReflection() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        navigationTab("Journey").tap()
        tap("Read your weekly reflection")
        XCTAssertTrue(app.navigationBars["Your weekly reflection"].waitForExistence(timeout: 5))
        let period = app.staticTexts["reflection.period"]
        let originalPeriod = period.label
        tap("reflection.earlier")
        XCTAssertNotEqual(period.label, originalPeriod)
        tap("reflection.later")
        XCTAssertEqual(period.label, originalPeriod)
        reveal(app.staticTexts["2 moments you kept"])
        capture("journal-weekly-reflection")
        tap("Done")
        XCTAssertTrue(app.navigationBars["Your journey"].waitForExistence(timeout: 5))
    }

    func testPreferencesSaveAndCancel() throws {
        throw XCTSkip("Retired with the Pip journal UI")

        launchSampleJourney()
        navigationTab("Settings").tap()
        tap("Your preferences")
        let wording = app.textFields["preferences.routine.movement"].exists ? app.textFields["preferences.routine.movement"] : app.textViews["preferences.routine.movement"]
        reveal(wording, centerInScroll: true); wording.tap(); wording.typeText("A gentle walk")
        tap("preferences.keyboardDone")
        tap("preferences.encouragement.straightforward")
        tap("preferences.save")
        navigationTab("Today").tap()
        let routine = app.buttons["today.routine.movement"]
        reveal(routine)
        XCTAssertTrue(routine.label.contains("A gentle walk"))
        app.terminate(); launchSandbox(reset: false)
        navigationTab("Settings").tap(); tap("Your preferences")
        XCTAssertTrue(app.buttons["preferences.encouragement.straightforward"].isSelected)
        tap("preferences.encouragement.celebratory")
        tap("preferences.cancel")
        tap("Your preferences")
        XCTAssertTrue(app.buttons["preferences.encouragement.straightforward"].isSelected, "Cancel must preserve the saved preference")
        capture("release-preferences")
    }

    // MARK: Protocol tracker

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testThreeMainDestinations() {
        launchSandbox(arguments: ["--setup-complete"])
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 8))
        XCTAssertFalse(navigationTab("Health").exists)
        navigationTab("Progress").tap()
        XCTAssertTrue(element("progress.adherence").waitForExistence(timeout: 4))
        navigationTab("Settings").tap()
        XCTAssertTrue(element("settings.weightUnit").waitForExistence(timeout: 4))
    }

    func testTodayLogsDosesAndDoseSheetSavesDetails() {
        launchSandbox(arguments: ["--setup-complete"])
        let summary = element("today.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 8))
        XCTAssertTrue(summary.label.contains("0") && summary.label.contains("2"), summary.label)
        capture("today-fresh")

        tap("today.dose.BPC-157.toggle")
        XCTAssertTrue(element("today.dose.BPC-157").value as? String == "Taken")
        tap("today.dose.BPC-157.toggle")
        XCTAssertTrue(element("today.dose.BPC-157").value as? String == "Not logged", "A second tap undoes the log")

        element("today.dose.Tirzepatide").tap()
        let amount = app.textFields["dose.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 4))
        XCTAssertEqual(amount.value as? String, "Amount", "Setup never prefills a dose amount")
        amount.tap(); amount.typeText("2.5")
        app.buttons["Done"].firstMatch.tap()
        tap("dose.site.choose")
        tap("site.area.abdomen")
        let spot = app.buttons["site.spot.abdomen.left.lower.1"]
        XCTAssertTrue(spot.waitForExistence(timeout: 6), "Zooming into the abdomen shows its spots")
        spot.tap()
        XCTAssertTrue(app.staticTexts["site.card.title"].label.contains("Lower left"))
        capture("site-picker")
        tap("site.use")
        let note = element("dose.note")
        reveal(note); note.tap(); note.typeText("First one. Felt fine.")
        capture("dose-sheet")
        tap("dose.save")
        XCTAssertTrue(element("today.dose.Tirzepatide").waitForExistence(timeout: 4))
        XCTAssertTrue(element("today.dose.Tirzepatide").label.contains("2.5"), element("today.dose.Tirzepatide").label)
        XCTAssertTrue(element("today.dose.Tirzepatide").label.contains("L abdomen"))
        XCTAssertEqual(element("today.dose.Tirzepatide").value as? String, "Taken")

        element("today.dose.Tirzepatide").tap()
        XCTAssertTrue(app.staticTexts["Last: L abdomen"].waitForExistence(timeout: 4) == false, "The record being edited is not its own last site")
        app.buttons["dose.close"].tap()

        tap("today.log-extra")
        XCTAssertTrue(app.buttons["dose.peptide.BPC-157"].waitForExistence(timeout: 4))
        app.buttons["dose.peptide.BPC-157"].tap()
        XCTAssertTrue(app.buttons["site.skip"].waitForExistence(timeout: 4), "Choosing a peptide opens the 3D site picker")
        capture("site-picker-whole-body")
        tap("site.skip")
        capture("dose-extra")
        tap("dose.save")
        XCTAssertTrue(element("today.dose.BPC-157").waitForExistence(timeout: 4))

        app.terminate()
        launchSandbox(reset: false)
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 8))
        XCTAssertTrue(element("today.summary").label.contains("1"), "Logs persist across launches")
    }

    func testProtocolAddsAndEditsPeptide() {
        launchSandbox(arguments: ["--setup-complete"])
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 8))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Your peptides"].tap()
        XCTAssertTrue(element("protocol.peptide.BPC-157").waitForExistence(timeout: 4))
        capture("protocol-list")

        tap("protocol.add")
        XCTAssertTrue(element("peptide.search").waitForExistence(timeout: 4))
        tap("peptide.pick.GHK-Cu")
        let amount = app.textFields["peptide.amount"]
        amount.tap(); amount.typeText("1")
        app.buttons["Done"].firstMatch.tap()
        tap("peptide.colour.teal")
        tap("peptide.schedule.weekdays")
        capture("peptide-editor")
        tap("peptide.save")
        XCTAssertTrue(element("protocol.peptide.GHK-Cu").waitForExistence(timeout: 4))

        element("protocol.peptide.GHK-Cu").tap()
        XCTAssertTrue(app.buttons["peptide.colour.teal"].isSelected)
        XCTAssertTrue(app.switches["peptide.pause"].waitForExistence(timeout: 4))
        app.switches["peptide.pause"].tap()
        tap("peptide.save")
        XCTAssertTrue(element("protocol.peptide.GHK-Cu").waitForExistence(timeout: 4))
        XCTAssertTrue(element("protocol.peptide.GHK-Cu").label.contains("Paused"), element("protocol.peptide.GHK-Cu").label)
    }
}
