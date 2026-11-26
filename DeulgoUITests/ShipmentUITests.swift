import XCTest

final class ShipmentUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func waitForKeyboardToClose(_ app: XCUIApplication) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor func testSendKeyboardDismissalAndBottomAction() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["home.send"].tap()
        let link = app.descendants(matching: .any)["shipment.link"].firstMatch
        let item = app.textFields["shipment.item"]
        let next = app.buttons["shipment.next"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["무엇을 보낼까요?"].firstMatch.exists)
        XCTAssertFalse(app.buttons["정보 다시 불러오기"].exists)
        XCTAssertTrue(next.isHittable)
        let bottomY = next.frame.minY
        capture("Send-form-keyboard-closed", app: app)

        link.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(next.exists)
        XCTAssertFalse(app.buttons["입력 완료"].exists)
        let close = app.buttons["shipment.dismissKeyboard"]
        XCTAssertTrue(close.isHittable)
        capture("Send-form-keyboard-open", app: app)
        close.tap()
        waitForKeyboardToClose(app)
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            next.exists && abs(next.frame.minY - bottomY) < 3
        }, object: next)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)

        item.tap()
        item.typeText("Test parcel")
        app.descendants(matching: .any)["링크가 없으면 물품명을 직접 적어주세요."].firstMatch.tap()
        waitForKeyboardToClose(app)
        XCTAssertEqual(item.value as? String, "Test parcel")

        link.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.scrollViews["shipment.itemScroll"].swipeDown()
        waitForKeyboardToClose(app)
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "주소 찾기")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testHomeOpensPublicRequestBoardDirectly() {
        let app = XCUIApplication()
        app.launch()
        let board = app.buttons["home.requestBoard"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["가는 김에 · 장거리 운반"].exists)
        capture("Home-long-distance-entry", app: app)
        board.tap()
        XCTAssertTrue(app.staticTexts["공개 요청 목록 준비 중"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["운반수단 등록"].exists)
        capture("Request-board-preparation", app: app)
    }
}
