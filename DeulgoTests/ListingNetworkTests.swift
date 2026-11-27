import XCTest
@testable import Deulgo

final class ListingNetworkTests: XCTestCase {
    func testFruitsAppShareRequiresTheExactHostTemplateAndCode() throws {
        let link = try ListingLink.parse("후루츠패밀리에서 확인해보세요! https://fruitsfamilyapp.onelink.me/Agm2/example1")
        XCTAssertEqual(link.platform, "후루츠패밀리")
        XCTAssertTrue(link.isShortLink)
        for input in ["https://fruitsfamilyapp.onelink.me/Agm2/", "https://another.onelink.me/Agm2/example1",
                      "https://fruitsfamilyapp.onelink.me.evil.test/Agm2/example1", "https://fruitsfamilyapp.onelink.me/Other/example1",
                      "https://fruitsfamilyapp.onelink.me/Agm2/example1/extra", "http://fruitsfamilyapp.onelink.me/Agm2/example1"] {
            XCTAssertThrowsError(try ListingLink.parse(input))
        }
    }

    func testShortLinksResolveBeforeProductLookupAndRemoveRedirectTracking() async throws {
        for (input, target, expected) in [
            ("https://fruitsfamilyapp.onelink.me/Agm2/example1", "https://fruitsfamily.com/product/abc12?deep_link_value=test&pid=share", "https://fruitsfamily.com/product/abc12"),
            ("https://go.bgzt.link/example1", "https://m.bunjang.co.kr/products/123456?airbridge_referrer=test", "https://m.bunjang.co.kr/products/123456")
        ] {
            var calls = 0
            let resolved = try await ListingShortLinkResolver.resolve(ListingLink.parse(input)) { url, _ in
                calls += 1
                XCTAssertEqual(url.absoluteString, input)
                return ListingHTTPResponse(status: 301, location: target, data: Data())
            }
            XCTAssertEqual(resolved.url.absoluteString, expected)
            XCTAssertEqual(calls, 1) // Do not load the target page just to resolve a redirect.
            XCTAssertFalse(resolved.isShortLink)
        }
    }

    func testResolverRefusesUnsafeOrCrossPlatformDestinationsWithoutFetchingThem() async throws {
        let link = try ListingLink.parse("https://go.bgzt.link/example1")
        for target in ["http://m.bunjang.co.kr/products/123456", "https://evil.test/products/123456", "https://127.0.0.1/",
                       "https://www.hellomarket.com/item/123456", "https://m.bunjang.co.kr/", "https://user:pass@m.bunjang.co.kr/products/123456"] {
            var calls = 0
            do {
                _ = try await ListingShortLinkResolver.resolve(link) { _, _ in
                    calls += 1
                    return ListingHTTPResponse(status: 302, location: target, data: Data())
                }
                XCTFail("Accepted unsafe redirect")
            } catch { XCTAssertEqual(calls, 1) }
        }
    }

    func testResolverStopsLoopsAndAccessDenialsWithoutRetrying() async throws {
        let link = try ListingLink.parse("https://fruitsfamilyapp.onelink.me/Agm2/example1")
        for status in [302, 403, 429, 200] {
            var calls = 0
            do {
                _ = try await ListingShortLinkResolver.resolve(link) { _, _ in
                    calls += 1
                    return ListingHTTPResponse(status: status, location: link.url.absoluteString, data: Data())
                }
                XCTFail("Unexpected resolved product")
            } catch { XCTAssertEqual(calls, 1) }
        }
    }

    private func productData(id: Int = 123456, title: String = "테스트 미니 PC", image: String = "https://media.bunjang.co.kr/product/123456_{cnt}_100_w{res}.jpg", hidden: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": ["product": ["pid": id, "name": title, "imageUrl": image, "imageCount": 3, "isHidden": hidden, "price": 999000, "qty": 5], "shop": ["name": "상품명이 아닌 상점명"]]])
    }

    func testBunjangPublicResponseUsesOnlyMatchingProductAndFirstPhoto() async throws {
        let link = try ListingLink.parse("https://m.bunjang.co.kr/products/123456")
        let fixture = try productData()
        let product = try await BunjangPublicProduct.load(link) { url, _ in
            XCTAssertEqual(url.absoluteString, "https://api.bunjang.co.kr/api/pms/v1/products/123456/detail/web")
            return ListingHTTPResponse(status: 200, location: nil, data: fixture)
        }
        XCTAssertEqual(product.title, "테스트 미니 PC")
        XCTAssertEqual(product.imageURL?.absoluteString, "https://media.bunjang.co.kr/product/123456_1_100_w320.jpg")
    }

    func testBunjangRejectsWrongHiddenOrGenericProductAndUnsafeImages() throws {
        for fixture in [try productData(id: 987654), try productData(title: "번개장터"), try productData(hidden: true), Data("{}".utf8)] {
            XCTAssertThrowsError(try BunjangPublicProduct.decode(fixture, productID: "123456"))
        }
        for image in ["https://evil.test/product/123456_1.jpg", "http://media.bunjang.co.kr/product/123456_1.jpg",
                      "https://media.bunjang.co.kr/product/987654_1.jpg", "https://user:pass@media.bunjang.co.kr/product/123456_1.jpg"] {
            let product = try BunjangPublicProduct.decode(productData(image: image), productID: "123456")
            XCTAssertEqual(product.title, "테스트 미니 PC")
            XCTAssertNil(product.imageURL)
        }
    }

    func testDaangnMetadataDropsPriceAndBrandSuffixButKeepsSellerNumbers() throws {
        XCTAssertEqual(try ListingMetadataTitle.productName("컴퓨터 풀세트 본체만 330 들었습니다 | 3,800,000원 | 당근 중고거래", platform: "당근"), "컴퓨터 풀세트 본체만 330 들었습니다")
        XCTAssertEqual(try ListingMetadataTitle.productName("2단 선반 | 나눔 | 당근 중고거래", platform: "당근"), "2단 선반")
        XCTAssertEqual(try ListingMetadataTitle.productName("선반 | 2단 | 당근 중고거래", platform: "당근"), "선반 | 2단")
        XCTAssertEqual(try ListingMetadataTitle.productName("3만원에 산 선반", platform: "당근"), "3만원에 산 선반")
        XCTAssertEqual(try ListingMetadataTitle.productName("선반 | 30,000원", platform: "헬로마켓"), "선반 | 30,000원")
    }

    @MainActor func testInvalidShareShowsErrorInsteadOfSilentlyReturning() async {
        let importer = ListingImporter()
        await importer.load("https://fruitsfamilyapp.onelink.me/Agm2/")
        XCTAssertNotNil(importer.error)
        XCTAssertNil(importer.preview)
        XCTAssertFalse(importer.busy)
        importer.reset()
        XCTAssertNil(importer.error)
    }
}
