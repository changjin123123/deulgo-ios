import XCTest
@testable import Deulgo

final class DestinationTests: XCTestCase {
    func testRejectsReversedCoordinatesAndNonfiniteValues() {
        for (lat, lng) in [(127.1, 37.5), (Double.nan, 127.0), (37.0, Double.infinity), (0.0, 0.0)] {
            XCTAssertThrowsError(try NavigationDestination(name: "장소", address: "", latitude: lat, longitude: lng))
        }
    }
    func testBoundsAndEmptyName() throws {
        XCTAssertNoThrow(try NavigationDestination(name: "경계", address: "", latitude: 31.43, longitude: 122.37))
        XCTAssertNoThrow(try NavigationDestination(name: "경계", address: "", latitude: 44.35, longitude: 132.00))
        XCTAssertThrowsError(try NavigationDestination(name: " \n ", address: "", latitude: 37.5, longitude: 127.0))
    }
    func testDecodedCoordinatesAreRevalidated() throws {
        let invalid = Data("""
        {"id":"E208714E-EE5C-4911-A345-06AF3D785077","name":"장소","address":"","latitude":127,"longitude":37}
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(NavigationDestination.self, from: invalid))
    }
    func testNaverPreservesKoreanAndReservedCharactersWithoutExtraParameters() throws {
        let name = "서울역 & A+B? # 2층 / 입구"
        let destination = try NavigationDestination(name: name, address: "서울", latitude: 37.5547, longitude: 126.9707)
        let url = try NaverNavigationURL.make(destination: destination, bundleIdentifier: "com.deulgo.delivery")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "nmap")
        XCTAssertEqual(components.host, "navigation")
        XCTAssertNil(components.fragment)
        let items = try XCTUnwrap(components.queryItems)
        XCTAssertEqual(items.count, 4)
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["dname"], name)
        XCTAssertEqual(values["dlat"], "37.5547")
        XCTAssertEqual(values["dlng"], "126.9707")
        XCTAssertEqual(values["appname"], "com.deulgo.delivery")
        XCTAssertNil(values["slat"]) // Current location is determined by the navigation app.
    }
    func testUnexpandedBuildSettingIsNotAKey() {
        for value in [nil, "", "$(KAKAO_NATIVE_APP_KEY)", "YOUR_KEY", "spaces are not keys"] as [String?] {
            XCTAssertNil(AppConfiguration.usableKakaoKey(value))
        }
        XCTAssertEqual(AppConfiguration.usableKakaoKey(" " + String(repeating: "a", count: 32)), String(repeating: "a", count: 32))
    }
}

@MainActor final class DraftTests: XCTestCase {
    func testPickupDropoffAndSelectedStopSurviveReloadAndCanBeDeleted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("draft.json")
        let store = DraftStore(fileURL: url)
        let pickup = try NavigationDestination(name: "픽업", address: "서울", latitude: 37.5, longitude: 127.0)
        let dropoff = try NavigationDestination(name: "도착", address: "부산", latitude: 35.1, longitude: 129.0)
        store.set(pickup, for: .pickup)
        store.set(dropoff, for: .dropoff)
        store.select(.dropoff)
        XCTAssertNil(store.storageMessage)
        let restored = DraftStore(fileURL: url)
        XCTAssertEqual(restored.draft.pickup, pickup)
        XCTAssertEqual(restored.draft.dropoff, dropoff)
        XCTAssertEqual(restored.draft.selectedDestination, dropoff)
        restored.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(restored.draft, NavigationDraft())
    }
    func testInvalidSavedDataIsNotUsedAsDestination() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("broken json".utf8).write(to: url)
        let store = DraftStore(fileURL: url)
        XCTAssertNotNil(store.storageMessage)
        XCTAssertNil(store.draft.selectedDestination)
    }
}

@MainActor private final class MockOpener: NavigationURLOpening {
    var installed = true
    var accepted = true
    var opened: [URL] = []
    func canOpen(_ url: URL) -> Bool { installed }
    func open(_ url: URL) async -> Bool { opened.append(url); return accepted }
}

@MainActor final class LaunchTests: XCTestCase {
    private var request: NavigationLaunchRequest {
        NavigationLaunchRequest(provider: .naver, url: URL(string: "nmap://navigation?dlat=37.5&dlng=127")!,
                                installURL: URL(string: "https://apps.apple.com/app/id311867728")!)
    }
    func testMissingAppOffersInstallWithoutAutomaticallyOpeningStore() async {
        let opener = MockOpener(); opener.installed = false
        let navigation = ExternalNavigation(opener: opener)
        await navigation.launch(request)
        XCTAssertTrue(opener.opened.isEmpty)
        XCTAssertEqual(navigation.notice?.installURL, request.installURL)
        XCTAssertFalse(navigation.isOpening)
    }
    func testRejectedLaunchReportsFailure() async {
        let opener = MockOpener(); opener.accepted = false
        let navigation = ExternalNavigation(opener: opener)
        await navigation.launch(request)
        XCTAssertEqual(opener.opened, [request.url])
        XCTAssertNotNil(navigation.notice)
        XCTAssertNil(navigation.notice?.installURL)
        XCTAssertFalse(navigation.isOpening)
    }
    func testAcceptedLaunchOnlyClearsError() async {
        let opener = MockOpener()
        let navigation = ExternalNavigation(opener: opener)
        await navigation.launch(request)
        XCTAssertEqual(opener.opened, [request.url])
        XCTAssertNil(navigation.notice)
        XCTAssertFalse(navigation.isOpening)
    }
    func testFailedStoreLaunchReportsFallback() async {
        let opener = MockOpener(); opener.accepted = false
        let navigation = ExternalNavigation(opener: opener)
        await navigation.openInstallPage(request.installURL)
        XCTAssertNotNil(navigation.notice)
        XCTAssertEqual(opener.opened, [request.installURL])
    }
}
