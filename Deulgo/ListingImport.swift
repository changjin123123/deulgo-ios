import Foundation
import LinkPresentation
import UIKit
import Combine

struct ListingLink {
    let url: URL
    let platform: String
    static func parse(_ input: String) throws -> ListingLink {
        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let links = detector.matches(in: input, range: NSRange(input.startIndex..., in: input))
        guard links.count == 1, let url = links.first?.url,
              var c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme == "https", c.user == nil, c.password == nil, c.port == nil,
              let host = c.host?.lowercased() else { throw AppInputError("공식 HTTPS 상품 링크를 하나만 붙여넣어주세요.") }
        let path = c.path
        func matches(_ pattern: String) -> Bool { path.range(of: pattern, options: .regularExpression) != nil }
        let platform: String
        if ["daangn.com", "www.daangn.com"].contains(host), matches("^/articles/[0-9]+/?$|^/kr/buy-sell/(?!all/?$|s/?$)[^/]+/?$") {
            platform = "당근"; c.host = "www.daangn.com"
        } else if ["bunjang.co.kr", "www.bunjang.co.kr", "m.bunjang.co.kr"].contains(host), matches("^/products/[0-9]+/?$") {
            platform = "번개장터"; c.host = "m.bunjang.co.kr"
        } else if host == "go.bgzt.link", matches("^/[A-Za-z0-9_-]{4,128}/?$") { platform = "번개장터" }
        else if ["joongna.com", "web.joongna.com"].contains(host), matches("^/product/[0-9]+/?$") {
            platform = "중고나라"; c.host = "web.joongna.com"
        } else { throw AppInputError("당근·번개장터·중고나라의 물품 판매글을 넣어주세요. 부동산·카페 링크는 상품 조회를 지원하지 않아요.") }
        c.query = nil; c.fragment = nil
        guard let result = c.url else { throw AppInputError("링크를 확인해주세요.") }
        return ListingLink(url: result, platform: platform)
    }
}

struct ListingPreview: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var imageData: Data?
    var dimensions: ItemDimensions?
}

@MainActor final class ListingImporter: ObservableObject {
    @Published private(set) var preview: ListingPreview?
    @Published private(set) var busy = false
    @Published private(set) var error: String?
    private var provider: LPMetadataProvider?
    private var generation = UUID()

    func reset() {
        generation = UUID(); provider?.cancel(); provider = nil
        preview = nil; error = nil; busy = false
    }
    func usePasted(_ text: String) {
        reset()
        preview = ReferenceData.shared.pastedListing(text)
        if preview == nil { error = "복사한 내용에서 물품명을 찾지 못했어요. 물품명을 직접 입력해주세요." }
    }
    func load(_ input: String) async {
        reset()
        let token = generation
        do {
            let link = try ListingLink.parse(input)
            busy = true
            let fetcher = LPMetadataProvider()
            fetcher.timeout = 12
            provider = fetcher
            let metadata: LPLinkMetadata = try await withCheckedThrowingContinuation { continuation in
                fetcher.startFetchingMetadata(for: link.url) { metadata, error in
                    if let metadata { continuation.resume(returning: metadata) }
                    else { continuation.resume(throwing: error ?? AppInputError("공개 상품 정보를 찾지 못했어요.")) }
                }
            }
            guard token == generation else { return }
            if let final = metadata.url {
                let resolved = try ListingLink.parse(final.absoluteString)
                guard resolved.platform == link.platform else { throw AppInputError("다른 서비스로 이동하는 링크는 사용하지 않아요.") }
            }
            let title = String((metadata.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
            guard title.count > 1, !["당근", "당근마켓", "번개장터", "중고나라"].contains(title),
                  title.range(of: "access denied|captcha|로그인|페이지를 찾을|just a moment", options: [.regularExpression, .caseInsensitive]) == nil else {
                throw AppInputError("공개 상품명을 확인하지 못했어요. 원문 내용을 복사하거나 직접 입력해주세요.")
            }
            // Keep metadata compact. Never turn the listing price into a delivery input.
            preview = ListingPreview(title: title, description: "", imageData: nil, dimensions: nil)
            if let imageProvider = metadata.imageProvider, imageProvider.canLoadObject(ofClass: UIImage.self) {
                imageProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    guard let image = object as? UIImage else { return }
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        let size = CGSize(width: 160, height: 160)
                        let thumbnail = UIGraphicsImageRenderer(size: size).image { _ in
                            let ratio = min(size.width / max(image.size.width, 1), size.height / max(image.size.height, 1))
                            let scaled = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                            image.draw(in: CGRect(x: (size.width - scaled.width) / 2, y: (size.height - scaled.height) / 2, width: scaled.width, height: scaled.height))
                        }
                        self.preview?.imageData = thumbnail.jpegData(compressionQuality: 0.7)
                    }
                }
            }
        } catch {
            guard token == generation else { return }
            self.error = (error as? AppInputError)?.message ?? "공개 상품 정보를 불러오지 못했어요. 원문 내용을 복사하거나 물품명을 직접 입력해주세요."
        }
        if token == generation { busy = false; provider = nil }
    }
}
