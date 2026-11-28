import XCTest
import StoreKitTest
import UIKit

final class AlongUITests: XCTestCase {
    private var app: XCUIApplication!
    private var journalSession = UUID()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        journalSession = UUID()
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
        let icons = ["Today": "house.fill", "Progress": "chart.bar.xaxis", "Settings": "gearshape"]
        return app.buttons.matching(identifier: icons[title] ?? title).matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Every launch, including persistence checks, stays in the UI-test data directory.
    private func launchSandbox(reset: Bool = true, arguments: [String] = []) {
        app.launchArguments = ["--ui-testing", "--test-journal", journalSession.uuidString] + (reset ? ["--reset-demo"] : []) + arguments
        app.launch()
    }

    private func capture(_ name: String) {
        if !name.hasPrefix("failure-") {
            // SwiftUI updates the accessibility tree before its slide and sheet transitions finish.
            let toast = element("journal.toast")
            if toast.exists { _ = toast.waitForNonExistence(timeout: 4) }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.8))
        }
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
            for identifier in ["setup.continue", "setup.subscribe", "peptide.save"] {
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
        case "doseTime":
            selectIfPresent("setup.weekday.2")
            selectIfPresent("setup.weekday.4")
        case "obstacles": selectIfPresent("setup.obstacle.forgetting")
        default: break
        }
        if step == "reminders" { tap("setup.reminders.skip") } else { tap("setup.continue") }
    }

    private let setupOrder = ["welcome", "experience", "goals", "source", "showcase", "pinMap", "birthday", "weight", "target",
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
        assertSetupStep("account")
        if last == "account" { return }
        fillAccountAndContinue()
        assertSetupStep("paywall")
    }

    private func fillAccountAndContinue() {
        let email = app.textFields["setup.account.email"]
        if !email.exists {
            XCTAssertTrue(app.buttons["setup.continue"].label.contains("this iPhone"))
            tap("setup.continue")
            return
        }
        reveal(email)
        email.tap()
        email.typeText("uitest@along.dev")
        let password = app.secureTextFields["setup.account.password"]
        if password.exists {
            reveal(password)
            password.tap()
            password.typeText("along-test-password")
        }
        tap("setup.continue")
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
        for tab in ["Progress", "Settings"] {
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
        for (index, step) in (setupOrder + ["plan", "account", "paywall"]).enumerated() {
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
        XCTAssertTrue(app.buttons["setup.skip-paywall"].waitForExistence(timeout: 3), "The development build offers an explicit preview")
        capture("setup-completed-paywall")
        tap("setup.skip-paywall")
        XCTAssertTrue(element("journal.preview").waitForExistence(timeout: 10))
        tap("today.log-extra")
        tap("dose.save")
        navigationTab("Progress").tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress.entry.")).firstMatch
        reveal(entry)
        XCTAssertTrue(entry.label.contains("BPC-157"))
        entry.tap()
        XCTAssertTrue(app.buttons["dose.delete"].exists)
        let note = element("dose.note")
        reveal(note)
        note.tap()
        note.typeText("Walkthrough record")
        tap("dose.save")
        XCTAssertTrue(entry.label.contains("Walkthrough record"))
        capture("progress-edited-history")
        app.terminate()
        launchSandbox(reset: false)
        navigationTab("Progress").tap()
        reveal(entry)
        XCTAssertTrue(entry.label.contains("Walkthrough record"))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress.entry.")).count, 1)

    }

    func testSetupWithoutWeightGoalSkipsWeightScreens() {
        launchSandbox()
        for step in ["welcome", "experience"] { assertSetupStep(step); answerAndContinue(step) }
        assertSetupStep("goals")
        selectIfPresent("setup.goal.skin")
        tap("setup.continue")
        for step in ["source", "showcase", "pinMap", "birthday"] { assertSetupStep(step); answerAndContinue(step) }
        assertSetupStep("commitment")
        tap("setup.back")
        assertSetupStep("birthday")
    }

    func testLocalStoreKitCheckoutAndRelaunch() throws {
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Along", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: file)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions() }

        launchSandbox(arguments: ["--setup-step", "paywall", "--local-storekit-test"])
        assertSetupStep("paywall")
        let subscribe = app.buttons["setup.subscribe"]
        let loaded = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: subscribe)
        wait(for: [loaded], timeout: 25)
        tap("setup.subscribe")
        XCTAssertTrue(navigationTab("Today").waitForExistence(timeout: 30))
        XCTAssertFalse(element("journal.preview").exists)
        XCTAssertEqual(session.allTransactions().first?.productIdentifier, "dev.along.membership.annual")
        navigationTab("Settings").tap()
        capture("local-storekit-membership")
        app.terminate()
        launchSandbox(reset: false, arguments: ["--local-storekit-test"])
        XCTAssertTrue(navigationTab("Today").waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["setup.subscribe"].exists)
    }

    /// Uses only the loopback Firebase emulators and Xcode's local StoreKit session.
    @MainActor func testAccountCheckoutBackupAndDeletion() async throws {
        let fixtureKey = "A" + String(repeating: "0", count: 38)
        let authURL = URL(string: "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(fixtureKey)")!
        let documentRoot = "http://127.0.0.1:8080/v1/projects/demo-along-uitest/databases/(default)/documents/users/"
        guard (try? await URLSession.shared.data(from: URL(string: "http://127.0.0.1:9099/")!)) != nil else {
            throw XCTSkip("Start the Along account emulators to exercise cloud backup and deletion.")
        }
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Along", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: file)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions() }
        let email = "walkthrough-\(UUID().uuidString.lowercased())@example.invalid"
        let password = "along-local-fixture"
        launchSandbox(arguments: ["--setup-step", "account", "--local-storekit-test", "--local-account-test"])
        let emailField = app.textFields["setup.account.email"]
        guard emailField.waitForExistence(timeout: 8) else { return XCTFail("The account form must appear after launch") }
        reveal(emailField)
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["setup.account.password"]
        reveal(passwordField)
        passwordField.tap()
        passwordField.typeText(password + "\n")
        let action = app.buttons["setup.subscribe"]
        guard action.waitForExistence(timeout: 8) else { return XCTFail("The account form must lead to checkout") }
        // Passwords can offer to save the login when the secure field disappears, before or after checkout.
        let prompt = app.sheets["Save Password?"]
        if prompt.waitForExistence(timeout: 8) { prompt.buttons["Not Now"].tap() }
        for _ in 0..<30 {
            if prompt.exists { prompt.buttons["Not Now"].tap() }
            if action.isEnabled && action.isHittable { break }
            try await Task.sleep(for: .seconds(1))
        }
        guard action.isEnabled && action.isHittable else { return XCTFail("Checkout must be ready to open") }
        action.tap()
        let today = navigationTab("Today")
        for _ in 0..<40 {
            if prompt.exists { prompt.buttons["Not Now"].tap() }
            if today.exists && today.isHittable { break }
            try await Task.sleep(for: .seconds(1))
        }
        guard today.exists && today.isHittable else { return XCTFail("Checkout must open Today") }
        if prompt.waitForExistence(timeout: 2) { prompt.buttons["Not Now"].tap() }
        let extra = app.buttons["today.log-extra"]
        guard extra.isHittable else { return XCTFail("The logged-in journal must offer an extra dose") }
        extra.tap()
        XCTAssertFalse(app.buttons["dose.save"].isEnabled)
        tap("dose.peptide.BPC-157")
        tap("site.skip")
        tap("dose.save")

        var signIn = URLRequest(url: authURL)
        signIn.httpMethod = "POST"
        signIn.setValue("application/json", forHTTPHeaderField: "Content-Type")
        signIn.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password, "returnSecureToken": true] as [String: Any])
        let (identityData, identityResponse) = try await URLSession.shared.data(for: signIn)
        XCTAssertEqual((identityResponse as? HTTPURLResponse)?.statusCode, 200)
        let identity = try XCTUnwrap(JSONSerialization.jsonObject(with: identityData) as? [String: Any])
        let uid = try XCTUnwrap(identity["localId"] as? String)
        var document = URLRequest(url: URL(string: documentRoot + uid + "/app/state")!)
        document.setValue("Bearer " + (try XCTUnwrap(identity["idToken"] as? String)), forHTTPHeaderField: "Authorization")
        var savedLogs = 0
        for _ in 0..<30 {
            let (data, _) = try await URLSession.shared.data(for: document)
            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let fields = response?["fields"] as? [String: [String: Any]]
            if let base64 = fields?["journalBase64"]?["stringValue"] as? String, let bytes = Data(base64Encoded: base64),
               let journal = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
                savedLogs = (journal["doseLogs"] as? [[String: Any]])?.count ?? 0
            }
            if savedLogs == 1 { break }
            try await Task.sleep(for: .seconds(1))
        }
        XCTAssertEqual(savedLogs, 1, "The authenticated backup contains the dose recorded in Today")

        navigationTab("Settings").tap()
        let delete = app.buttons["Delete account"]
        reveal(delete)
        delete.tap()
        let confirmation = app.secureTextFields["account.delete.password"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        confirmation.typeText(password)
        tap("account.delete.confirm")
        XCTAssertTrue(element("setup.screen.welcome").waitForExistence(timeout: 25))
        let (_, deletedIdentity) = try await URLSession.shared.data(for: signIn)
        XCTAssertEqual((deletedIdentity as? HTTPURLResponse)?.statusCode, 400)
        // The emulator's owner token lets the test inspect the document after the UID is gone.
        document.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        let (_, removedBackup) = try await URLSession.shared.data(for: document)
        XCTAssertEqual((removedBackup as? HTTPURLResponse)?.statusCode, 404)
    }

    @MainActor func testReturningAccountCanRecoverPasswordAndSignIn() async throws {
        let host = "http://127.0.0.1:9099"
        guard (try? await URLSession.shared.data(from: URL(string: host)!)) != nil else {
            throw XCTSkip("Start the local Auth emulator to exercise password recovery.")
        }
        let email = "recover-\(UUID().uuidString.lowercased())@example.invalid"
        let key = "A" + String(repeating: "0", count: 38)
        func accountRequest(_ action: String, _ data: [String: String]) async throws {
            var request = URLRequest(url: URL(string: host + "/identitytoolkit.googleapis.com/v1/accounts:" + action + "?key=" + key)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
            let (_, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        }
        try await accountRequest("signUp", ["email": email, "password": "original-local-password"])
        launchSandbox(arguments: ["--local-account-test"])
        tap("setup.sign-in")
        tap("setup.sign-in.email")
        let address = app.textFields["setup.sign-in.email.field"]
        reveal(address)
        address.tap()
        address.typeText(email + "\n")
        tap("setup.sign-in.reset-password")
        let notice = app.staticTexts["setup.sign-in.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(notice.label.contains("reset link"), notice.label)

        let codes = URL(string: host + "/emulator/v1/projects/demo-along-uitest/oobCodes")!
        let (data, _) = try await URLSession.shared.data(from: codes)
        let inbox = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try XCTUnwrap(inbox["oobCodes"] as? [[String: Any]])
        let reset = try XCTUnwrap(messages.first { $0["email"] as? String == email && $0["requestType"] as? String == "PASSWORD_RESET" })
        let password = "new-local-password"
        try await accountRequest("resetPassword", ["oobCode": try XCTUnwrap(reset["oobCode"] as? String), "newPassword": password])
        let field = app.secureTextFields["setup.sign-in.password.field"]
        reveal(field)
        field.tap()
        field.typeText(password + "\n")
        XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 15))
        XCTAssertFalse(navigationTab("Today").exists)
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
        assertSetupStep("account")
        tap("setup.back")
        assertSetupStep("plan")
        tap("setup.continue")
        assertSetupStep("account")
        tap("setup.continue")
        assertSetupStep("paywall")
    }

    func testWelcomeSignInSheetExplainsAccountsAndOffersRestore() {
        launchSandbox()
        assertSetupStep("welcome")
        tap("setup.sign-in")
        XCTAssertTrue(element("setup.sign-in.unavailable").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["setup.sign-in.apple"].exists)
        XCTAssertFalse(navigationTab("Today").exists)
        capture("setup-sign-in")
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
        assertSetupStep("pinMap")
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

    func testHealthDashboardShowsComposition() throws {
        throw XCTSkip("Health tab removed from the shipping tab bar")
    }

    func testTodayAddPeptideOpensProtocolSheet() {
        launchSandbox(arguments: ["--setup-complete"])
        // Wipe peptides via Settings so the empty CTA appears.
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Your peptides"].tap()
        // Sample setup still has peptides — open add path from Today empty state instead
        // by using a blank protocol scenario when available; otherwise verify Settings peptides.
        XCTAssertTrue(element("protocol.peptide.BPC-157").waitForExistence(timeout: 4)
                      || app.buttons["protocol.empty-add"].waitForExistence(timeout: 2))
        app.buttons["Done"].firstMatch.tap()
        app.tabBars.buttons["Today"].tap()
        if app.buttons["today.add-peptide"].waitForExistence(timeout: 3) {
            tap("today.add-peptide")
            XCTAssertTrue(app.navigationBars["Your peptides"].waitForExistence(timeout: 4)
                          || element("peptide.search").waitForExistence(timeout: 4)
                          || app.buttons["protocol.empty-add"].waitForExistence(timeout: 2)
                          || app.buttons["protocol.add"].waitForExistence(timeout: 2))
            capture("today-add-peptide-sheet")
        }
    }

    func testNextDoseOpensItsPlannedDay() {
        launchSandbox(arguments: ["--setup-complete"])
        tap("today.dose.BPC-157.toggle")
        tap("today.dose.Tirzepatide.toggle")
        tap("today.next")
        let summary = element("today.summary")
        XCTAssertTrue(summary.label.contains("Tomorrow") && summary.label.contains("planned"), summary.label)
        XCTAssertFalse(app.buttons["today.dose.BPC-157.toggle"].exists)
        XCTAssertFalse(app.buttons["today.log-extra"].exists)
        capture("next-planned-day")
    }

    func testOneTapDoseShowsActualTimeAndAppearsInCalendarWithoutANote() {
        launchSandbox(arguments: ["--setup-complete"])
        let before = Date.now
        tap("today.dose.BPC-157.toggle")
        let after = Date.now
        let row = element("today.dose.BPC-157")
        XCTAssertTrue([before, after].contains { row.label.contains("Taken at \($0.formatted(date: .omitted, time: .shortened))") }, row.label)
        navigationTab("Progress").tap()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        tap("progress.day.\(formatter.string(from: after))")
        let entry = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "progress.day-entry.", "BPC-157")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.label.contains("Taken"))
        entry.tap()
        XCTAssertTrue(app.buttons["dose.save"].waitForExistence(timeout: 5))
        let note = element("dose.note")
        reveal(note)
        note.tap()
        note.typeText("Calendar correction")
        tap("dose.save")
        XCTAssertTrue(entry.label.contains("Calendar correction"))
        capture("calendar-corrected-dose")
    }

    func testTodayLogsDosesAndDoseSheetSavesDetails() {
        launchSandbox(arguments: ["--setup-complete"])
        let summary = element("today.summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 8))
        XCTAssertTrue(summary.label.contains("0") && summary.label.contains("2"), summary.label)
        let title = element("today.title"), banner = element("journal.preview")
        XCTAssertTrue(title.exists && banner.exists)
        XCTAssertGreaterThanOrEqual(title.frame.minY, banner.frame.maxY, "The preview banner must leave the app title visible")
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
        XCTAssertFalse(app.buttons["dose.save"].isEnabled, "An extra dose needs a named peptide when several are tracked")
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
        tap("peptide.schedule.weekdays")
        tap("peptide.weekday.2")
        capture("peptide-editor")
        tap("peptide.save")
        XCTAssertTrue(element("protocol.peptide.GHK-Cu").waitForExistence(timeout: 4))

        element("protocol.peptide.GHK-Cu").tap()
        XCTAssertTrue(app.switches["peptide.pause"].waitForExistence(timeout: 4))
        app.switches["peptide.pause"].tap()
        tap("peptide.save")
        XCTAssertTrue(element("protocol.peptide.GHK-Cu").waitForExistence(timeout: 4))
        XCTAssertTrue(element("protocol.peptide.GHK-Cu").label.contains("Paused"), element("protocol.peptide.GHK-Cu").label)
    }

    private func openPeptideList() {
        navigationTab("Settings").tap()
        // The row's label includes its detail, e.g. "Your peptides, 2 tracked".
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Your peptides")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        reveal(row)
        row.tap()
        XCTAssertTrue(element("protocol.peptide.BPC-157").waitForExistence(timeout: 4))
    }

    func testPeptideColourPersistsAfterEditing() {
        launchSandbox(arguments: ["--setup-complete"])
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 8))
        openPeptideList()

        element("protocol.peptide.BPC-157").tap()
        let green = app.buttons["peptide.color.green"], teal = app.buttons["peptide.color.teal"]
        reveal(green, centerInScroll: true)
        XCTAssertTrue(green.isSelected && !teal.isSelected, "An untouched peptide shows its category colour")
        XCTAssertEqual(teal.label, "Teal")
        reveal(teal, centerInScroll: true)
        teal.tap()
        XCTAssertTrue(teal.isSelected && !green.isSelected)
        tap("peptide.save")
        XCTAssertTrue(element("protocol.peptide.BPC-157").waitForExistence(timeout: 4))

        element("protocol.peptide.BPC-157").tap()
        reveal(teal, centerInScroll: true)
        XCTAssertTrue(teal.isSelected && !green.isSelected, "The chosen colour is kept when editing again")
        tap("peptide.close")

        app.terminate()
        launchSandbox(reset: false)
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 8))
        openPeptideList()
        element("protocol.peptide.BPC-157").tap()
        reveal(teal, centerInScroll: true)
        XCTAssertTrue(teal.isSelected, "The chosen colour persists across launches")
    }

    /// Review captures for the colour feature. Tirzepatide is left untouched,
    /// so it shows exactly the colour it had before colours were editable.
    func testPeptideColoursReview() {
        launchSandbox(arguments: ["--setup-complete"])
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 8))
        openPeptideList()

        element("protocol.peptide.BPC-157").tap()
        tap("peptide.color.teal")
        tap("peptide.save")
        XCTAssertTrue(element("protocol.peptide.BPC-157").waitForExistence(timeout: 4))

        tap("protocol.add")
        tap("peptide.pick.GHK-Cu")
        XCTAssertTrue(app.buttons["peptide.color.pink"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["peptide.color.pink"].isSelected, "A new peptide follows its category until a swatch is tapped")
        tap("peptide.color.red")
        tap("peptide.schedule.daily")
        capture("colour-editor")
        tap("peptide.save")
        XCTAssertTrue(element("protocol.peptide.GHK-Cu").waitForExistence(timeout: 4))
        capture("colour-protocol-list")
        app.navigationBars.buttons["Done"].tap()

        navigationTab("Today").tap()
        XCTAssertTrue(element("today.summary").waitForExistence(timeout: 4))
        capture("colour-today")
        for name in ["BPC-157", "Tirzepatide", "GHK-Cu"] { tap("today.dose.\(name).toggle") }

        tap("today.log-extra")
        XCTAssertTrue(app.buttons["dose.peptide.GHK-Cu"].waitForExistence(timeout: 4))
        capture("colour-dose-sheet")
        app.buttons["dose.close"].tap()

        navigationTab("Progress").tap()
        // Found by label: the calendar's own identifier can mask identifiers inside it.
        let legend = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Colour key:")).firstMatch
        reveal(legend)
        XCTAssertEqual(legend.label, "Colour key: Tirzepatide, BPC-157, GHK-Cu")
        let todayCell = app.descendants(matching: .any).matching(NSPredicate(format: "label ENDSWITH %@", "Tirzepatide, BPC-157, GHK-Cu taken")).firstMatch
        XCTAssertTrue(todayCell.exists, "The day reads the peptides taken, in protocol order")
        capture("colour-progress-calendar")
    }
}
