import Foundation
import ImageIO
import UIKit

struct ListingHTTPResponse {
    let status: Int
    let location: String?
    let data: Data
}

// Inspect each redirect before making another request; no cookies or account credentials.
private final class ListingNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum ListingHTTP {
    typealias Fetch = (URL, Int) async throws -> ListingHTTPResponse

    static func fetch(_ url: URL, maxBytes: Int) async throws -> ListingHTTPResponse {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: URLRequest(url: url), delegate: ListingNoRedirect())
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse else { throw AppInputError("상품 링크 응답을 확인하지 못했어요.") }
        // Redirect/error bodies are unnecessary and may contain generic landing pages.
        guard (200...299).contains(http.statusCode) else {
            return ListingHTTPResponse(status: http.statusCode, location: http.value(forHTTPHeaderField: "Location"), data: Data())
        }
        guard response.expectedContentLength <= Int64(maxBytes) else { throw AppInputError("상품 정보가 너무 커서 불러오지 못했어요.") }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maxBytes else { throw AppInputError("상품 정보가 너무 커서 불러오지 못했어요.") }
            data.append(byte)
        }
        return ListingHTTPResponse(status: http.statusCode, location: nil, data: data)
    }

    static func image(_ url: URL) async throws -> Data {
        let response = try await fetch(url, maxBytes: 4_000_000)
        guard response.status == 200,
              let source = CGImageSourceCreateWithData(response.data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 320
              ] as CFDictionary), let data = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.75) else {
            throw AppInputError("상품 사진을 불러오지 못했어요.")
        }
        return data
    }
}

enum ListingShortLinkResolver {
    static func resolve(_ link: ListingLink, fetch: ListingHTTP.Fetch = ListingHTTP.fetch) async throws -> ListingLink {
        var current = link
        var visited = Set<String>()
        for _ in 0..<5 {
            try Task.checkCancellation()
            if !current.isShortLink { return current }
            guard visited.insert(current.url.absoluteString).inserted else { throw AppInputError("공유 링크가 반복 이동해요. 상품 페이지 주소를 복사해주세요.") }
            let response = try await fetch(current.url, 64_000)
            // OneLink can return a 200 launch page to CFNetwork on iOS instead
            // of an HTTP redirect. Read its explicit web destination as data;
            // never execute its script or open the external app/store scheme.
            if response.status == 200, current.url.host == "fruitsfamilyapp.onelink.me",
               let product = FruitsShareLanding.productLink(from: response.data) {
                return product
            }
            guard [301, 302, 303, 307, 308].contains(response.status),
                  let location = response.location,
                  let url = URL(string: location, relativeTo: current.url)?.absoluteURL,
                  let next = try? ListingLink.parse(url.absoluteString), next.platform == link.platform else {
                throw AppInputError("공유 링크의 상품 주소를 확인하지 못했어요. 원문에서 상품 페이지 주소를 복사하거나 물품명을 직접 입력해주세요.")
            }
            current = next
        }
        if !current.isShortLink { return current }
        throw AppInputError("공유 링크의 이동이 너무 많아요. 상품 페이지 주소를 복사해주세요.")
    }
}

enum FruitsShareLanding {
    static func productLink(from data: Data) -> ListingLink? {
        guard data.count <= 64_000, let html = String(data: data, encoding: .utf8) else { return nil }
        // Match one standalone string assignment from the observed OneLink
        // launch template. Reject expressions, duplicates and arbitrary links.
        let pattern = #"(?m)^[\t ]*var[\t ]+store_link[\t ]*=[\t ]*(?:"((?:\\.|[^"\\\r\n])*)"|'((?:\\.|[^'\\\r\n])*)')[\t ]*;[\t \r]*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        guard matches.count == 1, let match = matches.first else { return nil }
        let group = match.range(at: 1).location == NSNotFound ? 2 : 1
        guard let range = Range(match.range(at: group), in: html) else { return nil }
        let raw = String(html[range])
        // OneLink escapes URL separators as JSON-compatible \\u003D/\\u0026.
        // Single-quoted literals containing double quotes are outside this URL
        // format; refuse them rather than interpreting JavaScript escapes.
        guard group == 1 || !raw.contains("\"") else { return nil }
        guard let value = try? JSONSerialization.jsonObject(with: Data(("\"" + raw + "\"").utf8), options: .fragmentsAllowed) as? String,
              let link = try? ListingLink.parse(value), link.platform == "후루츠패밀리", !link.isShortLink else { return nil }
        return link
    }
}

struct BunjangPublicProduct {
    let title: String
    let imageURL: URL?

    // The public product page uses this unauthenticated response. It is not a
    // contracted partner API: fail clearly if its status or schema changes.
    static func load(_ link: ListingLink, fetch: ListingHTTP.Fetch = ListingHTTP.fetch) async throws -> BunjangPublicProduct {
        guard link.platform == "번개장터", !link.isShortLink,
              link.url.host == "m.bunjang.co.kr", let pid = link.url.pathComponents.last,
              pid.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
              let url = URL(string: "https://api.bunjang.co.kr/api/pms/v1/products/\(pid)/detail/web") else {
            throw AppInputError("번개장터 상품 주소를 확인해주세요.")
        }
        let response = try await fetch(url, 1_000_000)
        guard response.status == 200 else { throw AppInputError("번개장터의 공개 상품 정보를 불러오지 못했어요. 원문을 확인하거나 물품명을 직접 입력해주세요.") }
        return try decode(response.data, productID: pid)
    }

    static func decode(_ data: Data, productID: String) throws -> BunjangPublicProduct {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let body = root?["data"] as? [String: Any], let product = body["product"] as? [String: Any],
              let pid = product["pid"], String(describing: pid) == productID,
              (product["isHidden"] as? Bool) != true else { throw AppInputError("해당 상품의 공개 정보를 확인하지 못했어요.") }
        let title = try ListingMetadataTitle.productName(product["name"] as? String, platform: "번개장터")
        var imageURL: URL?
        if (product["imageCount"] as? Int ?? 0) > 0, let template = product["imageUrl"] as? String {
            let value = template.replacingOccurrences(of: "{cnt}", with: "1").replacingOccurrences(of: "{res}", with: "320")
            if let c = URLComponents(string: value), c.scheme == "https", c.host == "media.bunjang.co.kr",
               c.user == nil, c.password == nil, c.port == nil, c.query == nil, c.fragment == nil,
               c.path.hasPrefix("/product/\(productID)_"), !c.path.contains("..") {
                imageURL = c.url
            }
        }
        return BunjangPublicProduct(title: title, imageURL: imageURL)
    }
}
