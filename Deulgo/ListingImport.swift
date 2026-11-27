import Foundation
import LinkPresentation
import UIKit
import Combine

struct ListingLink {
    let url: URL
    let platform: String
    var isShortLink: Bool { ["go.bgzt.link", "fruitsfamilyapp.onelink.me"].contains(url.host ?? "") }
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
        } else if ["hellomarket.com", "www.hellomarket.com"].contains(host), matches("^/item/[0-9]+/?$") {
            platform = "헬로마켓"; c.host = "www.hellomarket.com"
        } else if ["fruitsfamily.com", "www.fruitsfamily.com", "production.fruitsfamily.com"].contains(host), matches("^/product/[A-Za-z0-9]+(?:/[^/]+)?/?$") {
            platform = "후루츠패밀리"; c.host = "fruitsfamily.com"
        } else if host == "fruitsfamilyapp.onelink.me", matches("^/Agm2/[A-Za-z0-9_-]{4,128}/?$") {
            platform = "후루츠패밀리"
        } else { throw AppInputError("지원하는 중고거래 사이트의 상품 링크를 넣어주세요. 홈·검색·부동산·카페 주소는 사용할 수 없어요.") }
        c.query = nil; c.fragment = nil
        guard let result = c.url else { throw AppInputError("링크를 확인해주세요.") }
        return ListingLink(url: result, platform: platform)
    }
}

enum ListingMetadataTitle {
    static func productName(_ raw: String?, platform: String) throws -> String {
        var title = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let generic = ["당근", "당근마켓", "번개장터", "중고나라", "헬로마켓", "후루츠패밀리", "fruitsfamily", "상품 상세", "상품상세",
                       "헬로마켓 - 수수료 없는 전국구 중고거래", "상품 상세 | 헬로마켓 - 수수료 없는 전국구 중고거래",
                       "후루츠패밀리 - 빈티지, 세컨핸드 패션 중고거래 앱", "후루츠패밀리 - 빈티지 세컨핸드 패션 중고거래"]
        let suffixes = platform == "당근" ? [" | 당근 중고거래", " | 당근마켓", " | 당근"] : [" | " + platform]
        if let suffix = suffixes.first(where: { title.hasSuffix($0) }) {
            title = String(title.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            // Only remove a separate price field attached by Daangn's metadata.
            // Numbers in the seller's title (model, size, quantity, etc.) remain intact.
            if platform == "당근" {
                title = title.replacingOccurrences(of: #"\s+\|\s+(?:[0-9][0-9,]*\s*원|나눔)\s*$"#, with: "", options: .regularExpression)
            }
        }
        guard title.count > 1, !generic.contains(title.lowercased()),
              title.range(of: "access denied|captcha|로그인|페이지를 찾을|just a moment", options: [.regularExpression, .caseInsensitive]) == nil else {
            throw AppInputError("공개 상품명을 확인하지 못했어요. 원문 내용을 복사하거나 직접 입력해주세요.")
        }
        return String(title.prefix(100))
    }
}

struct ListingPreview: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var imageData: Data?
    var dimensions: ItemDimensions?
}

struct ListingAutofill {
    private var importedTitle: String?
    private var importedDimensions = ItemDimensions()

    // Only replace empty or previously imported values, never edits made while loading.
    @discardableResult mutating func apply(_ preview: ListingPreview, to draft: inout ShipmentDraft) -> Bool {
        let mayFillTitle = draft.item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.item == importedTitle
        if mayFillTitle { draft.item = preview.title; importedTitle = preview.title }
        for key in [\ItemDimensions.width, \ItemDimensions.depth, \ItemDimensions.height] {
            if draft.dimensions[keyPath: key] == nil || draft.dimensions[keyPath: key] == importedDimensions[keyPath: key] {
                let value = preview.dimensions?[keyPath: key]
                draft.dimensions[keyPath: key] = value
                importedDimensions[keyPath: key] = value
            }
        }
        return mayFillTitle
    }

    mutating func clearImportedValues(from draft: inout ShipmentDraft) {
        if let importedTitle, draft.item == importedTitle { draft.item = "" }
        for key in [\ItemDimensions.width, \ItemDimensions.depth, \ItemDimensions.height] {
            if let value = importedDimensions[keyPath: key], draft.dimensions[keyPath: key] == value {
                draft.dimensions[keyPath: key] = nil
            }
        }
        importedTitle = nil
        importedDimensions = ItemDimensions()
    }
}

@MainActor final class ListingImporter: ObservableObject {
    @Published private(set) var preview: ListingPreview?
    @Published private(set) var busy = false
    @Published private(set) var error: String?
    private var provider: LPMetadataProvider?
    private var activeLoad: Task<Void, Never>?
    private var generation = UUID()

    func reset() {
        generation = UUID(); activeLoad?.cancel(); activeLoad = nil; provider?.cancel(); provider = nil
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
        let task = Task { await performLoad(input, token: token) }
        activeLoad = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        if token == generation { activeLoad = nil }
    }
    private func performLoad(_ input: String, token: UUID) async {
        do {
            let original = try ListingLink.parse(input)
            busy = true
            let link = try await ListingShortLinkResolver.resolve(original)
            try Task.checkCancellation()
            guard token == generation else { return }
            if link.platform == "번개장터" {
                let product = try await BunjangPublicProduct.load(link)
                try Task.checkCancellation()
                guard token == generation else { return }
                preview = ListingPreview(title: product.title, description: "", imageData: nil, dimensions: nil)
                if let url = product.imageURL, let data = try? await ListingHTTP.image(url) {
                    guard token == generation, !Task.isCancelled else { return }
                    preview?.imageData = data
                }
                if token == generation { busy = false }
                return
            }
            let fetcher = LPMetadataProvider()
            fetcher.timeout = 12
            provider = fetcher
            let metadata: LPLinkMetadata = try await withCheckedThrowingContinuation { continuation in
                fetcher.startFetchingMetadata(for: link.url) { metadata, error in
                    if let metadata { continuation.resume(returning: metadata) }
                    else { continuation.resume(throwing: error ?? AppInputError("공개 상품 정보를 찾지 못했어요.")) }
                }
            }
            guard token == generation, !Task.isCancelled else { return }
            if let final = metadata.url {
                let resolved = try ListingLink.parse(final.absoluteString)
                guard resolved.platform == link.platform else { throw AppInputError("다른 서비스로 이동하는 링크는 사용하지 않아요.") }
            }
            let title = try ListingMetadataTitle.productName(metadata.title, platform: link.platform)
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
            if !Task.isCancelled {
                self.error = (error as? AppInputError)?.message ?? "공개 상품 정보를 불러오지 못했어요. 원문 내용을 복사하거나 물품명을 직접 입력해주세요."
            }
        }
        if token == generation { busy = false; provider = nil }
    }
}
