import XCTest
@testable import Deulgo

final class RequestValidationTests: XCTestCase {
    private func validRequest() -> ShipmentDraft {
        var request = ShipmentDraft()
        request.item = "테스트 테이블"
        request.pickup.line = "테스트 픽업 주소"
        request.dropoff.line = "테스트 도착 주소"
        return request
    }
    func testUnknownMeasurementsAndYearAreAllowed() throws {
        XCTAssertNoThrow(try validRequest().validate())
        var vehicle = VehicleProfile(); vehicle.model = "쏘나타"
        XCTAssertNoThrow(try vehicle.validate(currentYear: 2026))
    }
    func testInvalidDimensionIsNotTreatedAsUnknown() {
        for number in [Double.nan, Double.infinity, -1, 0, 1001] {
            var request = validRequest(); request.dimensions.width = number
            XCTAssertThrowsError(try request.validate())
        }
    }
    func testPastScheduleAndMissingAddressAreRejected() {
        var request = validRequest(); request.arrival = .scheduled; request.desiredAt = Date(timeIntervalSince1970: 10)
        XCTAssertThrowsError(try request.validate(now: Date(timeIntervalSince1970: 20)))
        request.arrival = .flexible; request.pickup.line = "  "
        XCTAssertThrowsError(try request.validate())
    }
    func testEditingAddressInvalidatesCoordinates() throws {
        var address = DeliveryAddress()
        address.select(try NavigationDestination(name: "장소", address: "기본 주소", latitude: 37.5, longitude: 127))
        address.detail = "상세주소"
        XCTAssertNotNil(address.place)
        address.editLine("다른 기본주소")
        XCTAssertNil(address.place)
    }
    func testOldVehicleYearIsRejected() {
        var vehicle = VehicleProfile(); vehicle.model = "모델"; vehicle.year = 2009
        XCTAssertThrowsError(try vehicle.validate(currentYear: 2026))
        vehicle.year = 2010
        XCTAssertNoThrow(try vehicle.validate(currentYear: 2026))
    }
    func testListingRequiresProductHostPathAndSingleLink() throws {
        let link = try ListingLink.parse("당근에서 이 글을 확인해보세요! https://www.daangn.com/articles/1295039589?share=true")
        XCTAssertEqual(link.platform, "당근")
        XCTAssertNil(URLComponents(url: link.url, resolvingAgainstBaseURL: false)?.query)
        for value in ["https://realty.daangn.com/articles/5152225", "https://www.daangn.com.evil.test/articles/1", "https://www.daangn.com/articles/1 https://m.bunjang.co.kr/products/2", "http://www.daangn.com/articles/1"] {
            XCTAssertThrowsError(try ListingLink.parse(value))
        }
    }
    func testBuyerDraftAllowsPendingPickupButStillRequiresDropoff() {
        var request = validRequest(); request.pickup = DeliveryAddress()
        XCTAssertNoThrow(try request.validate(requirePickup: false))
        XCTAssertThrowsError(try request.validate())
        request.dropoff.line = "  "
        XCTAssertThrowsError(try request.validate(requirePickup: false))
    }
    func testListingAutofillsTitleWithoutAssumingQuantityOrPackaging() {
        var request = ShipmentDraft()
        var fill = ListingAutofill()
        let preview = ListingPreview(title: "의자 세트", description: "", dimensions: ItemDimensions(width: 60, depth: 40, height: 80))
        XCTAssertTrue(fill.apply(preview, to: &request))
        XCTAssertEqual(request.item, "의자 세트")
        XCTAssertEqual(request.dimensions, preview.dimensions)
        XCTAssertNil(request.count)
        XCTAssertEqual(request.packaging, "판매자 확인 필요")
        XCTAssertEqual(request.orientation, .unknown)
    }
    func testAutofillPreservesEditsAndClearsOnlyOldImportedValues() {
        var request = ShipmentDraft()
        var fill = ListingAutofill()
        fill.apply(ListingPreview(title: "테이블", description: "", dimensions: ItemDimensions(width: 60, depth: 40, height: 80)), to: &request)
        request.item = "내가 선택한 구성"
        request.dimensions.width = 75
        fill.clearImportedValues(from: &request)
        XCTAssertEqual(request.item, "내가 선택한 구성")
        XCTAssertEqual(request.dimensions.width, 75)
        XCTAssertNil(request.dimensions.depth)
        XCTAssertNil(request.dimensions.height)
        XCTAssertFalse(fill.apply(ListingPreview(title: "새 거래글", description: "", dimensions: ItemDimensions(width: 20, depth: 30, height: 40)), to: &request))
        XCTAssertEqual(request.item, "내가 선택한 구성")
        XCTAssertEqual(request.dimensions.width, 75)
        XCTAssertEqual(request.dimensions.depth, 30)
    }
    func testRemovingLinkClearsAutofillAndMissingNewDimensionsDoNotStayStale() {
        var request = ShipmentDraft()
        var fill = ListingAutofill()
        fill.apply(ListingPreview(title: "첫 물품", description: "", dimensions: ItemDimensions(width: 60, depth: 40, height: 80)), to: &request)
        fill.apply(ListingPreview(title: "다른 물품", description: "", dimensions: nil), to: &request)
        XCTAssertEqual(request.item, "다른 물품")
        XCTAssertEqual(request.dimensions, ItemDimensions())
        fill.clearImportedValues(from: &request)
        XCTAssertTrue(request.item.isEmpty)
    }
    func testExistingQuantityAndPackagingDecodeWhileNewUnknownValuesRoundTrip() throws {
        var oldRequest = validRequest()
        oldRequest.count = 3; oldRequest.orientation = .upright; oldRequest.packaging = "포장했어요"
        let existing = try JSONDecoder().decode(ShipmentDraft.self, from: JSONEncoder().encode(oldRequest))
        XCTAssertEqual(existing, oldRequest)
        var withoutCount = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ShipmentDraft())) as? [String: Any])
        withoutCount.removeValue(forKey: "count")
        let unknown = try JSONDecoder().decode(ShipmentDraft.self, from: JSONSerialization.data(withJSONObject: withoutCount))
        XCTAssertNil(unknown.count)
        XCTAssertEqual(unknown.orientation, .unknown)
    }
}

@MainActor final class AppPersistenceTests: XCTestCase {
    func testRequestVehicleAndAddressRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("data.json")
        let store = DeulgoStore(fileURL: url)
        var request = ShipmentDraft(); request.item = "테스트"; request.pickup.line = "주소 A"; request.dropoff.line = "주소 B"
        try store.save(request)
        var vehicle = VehicleProfile(); vehicle.model = "쏘나타"
        try store.save(vehicle)
        try store.saveAddress(request.pickup, label: "픽업")
        try store.saveAddress(request.pickup, label: "중복")
        let restored = DeulgoStore(fileURL: url)
        XCTAssertEqual(restored.data.requests.first?.id, request.id)
        XCTAssertEqual(restored.data.vehicles, [vehicle])
        XCTAssertEqual(restored.data.addresses.count, 1)
        request.item = "수정"; try restored.save(request)
        XCTAssertEqual(restored.data.requests.count, 1)
        try restored.deleteRequest(request.id)
        XCTAssertTrue(DeulgoStore(fileURL: url).data.requests.isEmpty)
    }
    func testUnreadableStoreDoesNotOverwriteOriginal() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("broken".utf8); try original.write(to: url)
        let store = DeulgoStore(fileURL: url)
        var vehicle = VehicleProfile(); vehicle.model = "모델"
        XCTAssertThrowsError(try store.save(vehicle))
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertTrue(store.data.vehicles.isEmpty)
    }
    func testFailedWriteDoesNotReportSavedState() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("not a directory".utf8).write(to: file)
        let store = DeulgoStore(fileURL: file.appendingPathComponent("child.json"))
        var vehicle = VehicleProfile(); vehicle.model = "모델"
        XCTAssertThrowsError(try store.save(vehicle))
        XCTAssertTrue(store.data.vehicles.isEmpty)
    }
    func testBundledReferenceRulesLoadAndSupportInitials() {
        XCTAssertFalse(ReferenceData.shared.unavailable)
        XCTAssertFalse(ReferenceData.shared.catalog.isEmpty)
        XCTAssertTrue(ReferenceData.shared.models(kind: .car, query: "ㅆㄴㅌ").contains { $0.name == "쏘나타" })
        let pasted = ReferenceData.shared.pastedListing("물품명: 테이블\n150,000원\n가로 60 깊이 40 높이 80cm")
        XCTAssertEqual(pasted?.title, "테이블")
        XCTAssertEqual(pasted?.dimensions?.width, 60)
        XCTAssertFalse(pasted?.description.contains("150,000") ?? true)
    }
    func testPendingPickupAndUnknownQuantitySurviveDraftStorage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("data.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = DeulgoStore(fileURL: url)
        var request = ShipmentDraft(); request.item = "의자 세트"; request.dropoff.line = "받을 곳"
        try store.save(request)
        let restored = try XCTUnwrap(DeulgoStore(fileURL: url).data.requests.first)
        XCTAssertEqual(restored.pickup, DeliveryAddress())
        XCTAssertNil(restored.count)
        XCTAssertEqual(restored.orientation, .unknown)
    }
    func testUnknownQuantityOrOrientationCannotBecomePositiveFit() {
        var request = ShipmentDraft(); request.item = "의자"; request.dimensions = ItemDimensions(width: 30, depth: 40, height: 50)
        var vehicle = VehicleProfile(); vehicle.model = "테스트"; vehicle.measurements = VehicleMeasurements(openingWidth: 100, openingHeight: 100, insideWidth: 100, insideDepth: 100, insideHeight: 100)
        XCTAssertTrue(ReferenceData.shared.fit(request: request, vehicle: vehicle).contains("수량"))
        request.count = 1
        XCTAssertTrue(ReferenceData.shared.fit(request: request, vehicle: vehicle).contains("눕히거나"))
        request.orientation = .any
        XCTAssertTrue(ReferenceData.shared.fit(request: request, vehicle: vehicle).contains("입력한 치수 조건은 맞아요"))
    }
}
