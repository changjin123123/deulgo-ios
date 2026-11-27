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

    func testBunjangIOSAirbridgeRedirectResolvesWithoutLoadingTheLaunchPage() async throws {
        let original = try ListingLink.parse("https://go.bgzt.link/example1")
        var calls = 0
        let product = try await ListingShortLinkResolver.resolve(original) { url, _ in
            calls += 1
            XCTAssertEqual(url, original.url)
            return ListingHTTPResponse(status: 302,
                location: "https://bunjang.airbridge.io/goto?type=product&val=123456&airbridge_referrer=test&https_deeplink=true&short_id=example1",
                data: Data())
        }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(product.url.absoluteString, "https://m.bunjang.co.kr/products/123456")
        XCTAssertEqual(product.platform, "번개장터")
        XCTAssertFalse(product.isShortLink)
    }

    func testBunjangAirbridgeRejectsUnsafeOrAmbiguousDestinations() throws {
        let root = "https://bunjang.airbridge.io/goto"
        let invalid = [
            "http://bunjang.airbridge.io/goto?type=product&val=123456",
            "https://other.airbridge.io/goto?type=product&val=123456",
            "https://bunjang.airbridge.io.evil.test/goto?type=product&val=123456",
            "https://user:pass@bunjang.airbridge.io/goto?type=product&val=123456",
            "https://bunjang.airbridge.io:443/goto?type=product&val=123456",
            "https://bunjang.airbridge.io/other?type=product&val=123456",
            root + "?type=product&val=123456#other", root + "?type=shop&val=123456",
            root + "?val=123456", root + "?type=product", root + "?type=product&val=",
            root + "?type=product&val=123456&val=654321",
            root + "?type=product&val=123456&VAL=654321",
            root + "?type=product&type=shop&val=123456",
            root + "?type=product&val=-123456", root + "?type=product&val=123456%0A",
            root + "?type=product&val=123456%2Fother", root + "?type=product&val=https%3A%2F%2Fevil.test",
            root + "?type=product&val=" + String(repeating: "1", count: 21)
        ]
        for value in invalid {
            XCTAssertNil(BunjangShareDestination.productLink(from: try XCTUnwrap(URL(string: value))), value)
        }
    }

    func testBunjangAirbridgeRequiresBunjangOriginAndHTTPRedirect() async throws {
        let target = "https://bunjang.airbridge.io/goto?type=product&val=123456"
        for (input, status) in [("https://go.bgzt.link/example1", 200),
                                ("https://go.bgzt.link/example1", 403),
                                ("https://go.bgzt.link/example1", 429),
                                ("https://fruitsfamilyapp.onelink.me/Agm2/example1", 302)] {
            var calls = 0
            do {
                _ = try await ListingShortLinkResolver.resolve(ListingLink.parse(input)) { _, _ in
                    calls += 1
                    return ListingHTTPResponse(status: status, location: target, data: Data())
                }
                XCTFail("Accepted an unrelated or denied redirect")
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

    func testFruitsIOSLaunchPageResolvesItsEscapedWebDestination() async throws {
        let link = try ListingLink.parse("https://fruitsfamilyapp.onelink.me/Agm2/example1")
        // Synthetic values; structure follows OneLink's actual iOS launch page.
        let fixture = #"""
        <!DOCTYPE html><title>Launching App...</title>
        <script>
        var store_link = 'https://fruitsfamily.com/product/abc12?source_caller\u003Dsdk\u0026deep_link_value\u003Dhttps%3A%2F%2Ffruitsfamily.com%2Fproduct%2Fabc12';
        var app_link = 'fruitsfamily://mainactivity?deep_link_value=unrelated';
        var app_icon = 'https://cdnappicons.appsflyer.com/icon.png';
        </script>
        """#
        var calls = 0
        let product = try await ListingShortLinkResolver.resolve(link) { url, limit in
            calls += 1
            XCTAssertEqual(url, link.url)
            XCTAssertEqual(limit, 64_000)
            return ListingHTTPResponse(status: 200, location: nil, data: Data(fixture.utf8))
        }
        XCTAssertEqual(product.url.absoluteString, "https://fruitsfamily.com/product/abc12")
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(product.isShortLink)
        let doubleQuoted = #"var store_link = "https:\/\/fruitsfamily.com\/product\/abc12";"#
        XCTAssertEqual(FruitsShareLanding.productLink(from: Data(doubleQuoted.utf8))?.url, product.url)
    }

    func testFruitsLaunchPageRejectsUnsafeAmbiguousAndExecutableValues() {
        let invalid = [
            "var store_link = 'https://evil.test/product/abc12';",
            "var store_link = 'http://fruitsfamily.com/product/abc12';",
            "var store_link = 'https://user:pass@fruitsfamily.com/product/abc12';",
            "var store_link = 'https://www.hellomarket.com/item/123456';",
            "var store_link = 'https://fruitsfamily.com/';",
            "var store_link = 'https://fruitsfamilyapp.onelink.me/Agm2/example1';",
            "var store_link = 'fruitsfamily://mainactivity';",
            "var store_link = 'https://fruitsfamily.com/product/' + productID;",
            "var store_link = getDestination();",
            "var app_link = 'https://fruitsfamily.com/product/abc12';",
            "var store_link = 'https://fruitsfamily.com/product/abc12';\nvar store_link = 'https://fruitsfamily.com/product/other';",
            "<title>Launching App...</title>",
            String(repeating: " ", count: 64_001)
        ]
        for html in invalid {
            XCTAssertNil(FruitsShareLanding.productLink(from: Data(html.utf8)))
        }
    }

    func testLaunchHTMLIsNotUsedForDeniedResponsesOrAnotherService() async throws {
        let body = Data("var store_link = 'https://fruitsfamily.com/product/abc12';".utf8)
        for (url, status) in [("https://fruitsfamilyapp.onelink.me/Agm2/example1", 403),
                              ("https://fruitsfamilyapp.onelink.me/Agm2/example1", 429),
                              ("https://go.bgzt.link/example1", 200)] {
            var calls = 0
            do {
                _ = try await ListingShortLinkResolver.resolve(ListingLink.parse(url)) { _, _ in
                    calls += 1
                    return ListingHTTPResponse(status: status, location: nil, data: body)
                }
                XCTFail("Accepted untrusted launch response")
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
