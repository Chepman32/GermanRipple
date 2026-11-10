import StoreKitTest
import UIKit
import XCTest

final class RippleUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }
  @MainActor func testExpandedScenariosRemainReachableThroughLongSentences() throws {
    for id in ["de.a2.cafe.001", "de.b1.despite.008"] {
      let app = XCUIApplication()
      app.launchArguments = ["--uitesting", "--skip-onboarding", "--chain=\(id)"]
      app.launch()
      for _ in 0..<8 {
        if app.buttons["summary.next"].exists { break }
        XCTAssertTrue(app.buttons["player.card"].waitForExistence(timeout: 10))
        app.buttons["player.card"].tap()
        let target = app.buttons.matching(NSPredicate(format: "value == %@", "Change card target")).firstMatch
        if target.exists { target.tap() }
        let slot = app.buttons.matching(NSPredicate(format: "value == %@", "Suggested insertion point")).firstMatch
        if slot.exists { slot.tap() }
        XCTAssertTrue(app.buttons["player.check"].waitForExistence(timeout: 3))
        app.buttons["player.check"].tap()
        if app.buttons["player.check"].exists { app.buttons["player.check"].tap() }
        XCTAssertTrue(app.buttons["player.next"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["player.next"].isHittable)
        app.buttons["player.next"].tap()
      }
      XCTAssertTrue(app.buttons["summary.next"].waitForExistence(timeout: 3))
      XCTAssertTrue(app.staticTexts["summary.heading"].isHittable)
      capture(app, "Expanded scenario \(id)")
      app.buttons["Done for now"].tap()
      app.terminate()
    }
  }
  @MainActor func testPaywallUsesSelectedProductsAndAlwaysDismisses() throws {
    let url = try XCTUnwrap(
      Bundle(for: Self.self).url(forResource: "Ripple", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: url)
    session.disableDialogs = true
    session.clearTransactions()
    defer { session.clearTransactions() }
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--skip-onboarding"]
    app.launch()
    selectTab("Settings", in: app)
    let explore = app.buttons["settings.pro"]
    for _ in 0..<8 {
      if explore.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(explore.isHittable)
    explore.tap()
    let monthly = app.buttons["plan.app.ripple.pro.monthly"]
    XCTAssertTrue(monthly.waitForExistence(timeout: 15))
    for _ in 0..<5 {
      if monthly.isHittable { break }
      app.swipeUp()
    }
    monthly.tap()
    let purchase = app.buttons["paywall.purchase"]
    XCTAssertTrue(purchase.waitForExistence(timeout: 3))
    XCTAssertTrue(purchase.label.contains("Continue with Monthly"))
    XCTAssertFalse(purchase.label.contains("free trial"))
    for _ in 0..<5 {
      if purchase.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(purchase.isHittable)
    capture(app, "Paywall monthly terms")
    app.buttons["paywall.close"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
  }
  @MainActor func testSpawnedWordHasTapOnlyFormAndPlacement() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--skip-onboarding", "--chain=de.a1.past.000"]
    app.launch()
    XCTAssertTrue(app.buttons["player.card"].waitForExistence(timeout: 10))
    app.buttons["player.card"].tap()
    app.buttons["token.s"].tap()
    app.buttons["token.v"].tap()
    app.buttons["form.lernen"].tap()
    app.buttons["player.next"].tap()
    app.buttons["player.card"].tap()
    app.buttons.matching(NSPredicate(format: "value == %@", "Suggested insertion point")).firstMatch
      .tap()
    app.buttons["token.v"].tap()
    app.buttons["form.haben"].tap()
    app.buttons["spawn.p"].tap()
    app.buttons["form.gelernt"].tap()
    app.buttons["Choose its position"].tap()
    app.buttons["slot.4"].tap()
    XCTAssertTrue(app.buttons["player.next"].waitForExistence(timeout: 3))
    capture(app, "Resolved past tense")
  }
  @MainActor func testLargestDynamicTypeKeepsLessonActionsReachable() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--uitesting", "-UIPreferredContentSizeCategoryName",
      UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue,
    ]
    app.launch()
    XCTAssertTrue(app.buttons["onboarding.try"].waitForExistence(timeout: 10))
    app.buttons["onboarding.try"].tap()
    app.buttons["player.card"].tap()
    app.buttons["token.s"].tap()
    app.buttons["token.v"].tap()
    app.buttons["form.trinken"].tap()
    XCTAssertTrue(app.buttons["player.next"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["player.next"].isHittable)
    capture(app, "Accessibility XXXL lesson")
  }
  @MainActor func testFullChainCanAlwaysFinishAndAppearsInGallery() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--skip-onboarding"]
    app.launch()
    XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 15))
    capture(app, "Today")
    app.buttons["today.start"].tap()
    for _ in 0..<8 {
      if app.buttons["summary.next"].exists { break }
      XCTAssertTrue(app.buttons["player.card"].waitForExistence(timeout: 3))
      app.buttons["player.card"].tap()
      let target = app.buttons.matching(NSPredicate(format: "value == %@", "Change card target"))
        .firstMatch
      if target.exists { target.tap() }
      let slot = app.buttons.matching(
        NSPredicate(format: "value == %@", "Suggested insertion point")
      ).firstMatch
      if slot.exists { slot.tap() }
      XCTAssertTrue(app.buttons["player.check"].waitForExistence(timeout: 3))
      app.buttons["player.check"].tap()
      if app.buttons["player.check"].exists { app.buttons["player.check"].tap() }
      XCTAssertTrue(app.buttons["player.next"].waitForExistence(timeout: 3))
      app.buttons["player.next"].tap()
    }
    XCTAssertTrue(app.buttons["summary.next"].waitForExistence(timeout: 3))
    capture(app, "Chain summary")
    app.buttons["Done for now"].tap()
    selectTab("Gallery", in: app)
    XCTAssertFalse(app.staticTexts["Your words belong here."].exists)
    capture(app, "Gallery")
    selectTab("Rules", in: app)
    capture(app, "Rule map")
    selectTab("Settings", in: app)
    capture(app, "Settings")
  }
  @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  @MainActor private func selectTab(_ title: String, in app: XCUIApplication) {
    let phoneTab = app.tabBars.buttons[title]
    if phoneTab.exists {
      phoneTab.tap()
      return
    }
    // iPadOS's floating selector can expose both its cell and inner view as
    // button aliases. Select an actual visible match instead of requiring a TabBar.
    let buttons = app.buttons.matching(identifier: title)
    XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 10))
    guard let button = buttons.allElementsBoundByIndex.first(where: \.isHittable) else {
      XCTFail("The \(title) tab must be visible and accessible.")
      return
    }
    button.tap()
  }
  @MainActor func testTapOnlyDemoThenBeginnerOnboarding() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
    XCTAssertTrue(app.buttons["onboarding.try"].waitForExistence(timeout: 15))
    app.buttons["onboarding.try"].tap()
    XCTAssertTrue(app.buttons["player.card"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["player.card"].label.contains("wir: we"))
    app.buttons["player.card"].tap()
    app.buttons["token.s"].tap()
    app.buttons["token.v"].tap()
    app.buttons["form.trinken"].tap()
    XCTAssertTrue(app.buttons["player.next"].waitForExistence(timeout: 3))
    app.buttons["player.next"].tap()
    app.buttons["player.card"].tap()
    app.buttons["slot.2"].tap()
    app.buttons["token.d"].tap()
    XCTAssertTrue(app.navigationBars["ein"].waitForExistence(timeout: 3))
    app.buttons["form.einen"].tap()
    app.buttons["player.next"].tap()
    app.buttons["player.card"].tap()
    app.buttons["slot.3"].tap()
    app.buttons["token.a"].tap()
    app.buttons["form.großen"].tap()
    app.buttons["player.next"].tap()
    XCTAssertTrue(app.buttons["summary.next"].waitForExistence(timeout: 3))
    app.buttons["summary.next"].tap()
    XCTAssertTrue(app.buttons["onboarding.beginner"].waitForExistence(timeout: 3))
    app.buttons["onboarding.beginner"].tap()
    app.buttons["onboarding.finish"].tap()
    if app.buttons["consent.decline"].waitForExistence(timeout: 3) {
      app.buttons["consent.decline"].tap()
    }
    XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 5))
    selectTab("Rules", in: app)
    XCTAssertTrue(app.navigationBars["Rules"].exists)
    selectTab("Gallery", in: app)
    XCTAssertTrue(app.staticTexts["Your words belong here."].exists)
    selectTab("Settings", in: app)
    XCTAssertTrue(app.switches["Always guided"].exists)
  }
  @MainActor func testSaveAndResumeAndRevealNeverBlocks() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--skip-onboarding"]
    app.launch()
    XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 15))
    app.buttons["today.start"].tap()
    XCTAssertTrue(app.buttons["player.card"].waitForExistence(timeout: 3))
    app.buttons["player.card"].tap()
    let target = app.buttons.matching(NSPredicate(format: "value == %@", "Change card target"))
      .firstMatch
    if target.exists { target.tap() }
    let slot = app.buttons.matching(NSPredicate(format: "value == %@", "Suggested insertion point"))
      .firstMatch
    if slot.exists { slot.tap() }
    XCTAssertTrue(app.buttons["player.check"].waitForExistence(timeout: 3))
    app.buttons["player.check"].tap()
    app.buttons["player.check"].tap()
    app.buttons["player.close"].tap()
    XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["today.start"].label.contains("Continue your chain"))
    app.buttons["today.start"].tap()
    XCTAssertTrue(app.buttons["player.next"].waitForExistence(timeout: 3))
  }
}
