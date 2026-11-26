import Foundation

enum DestinationError: LocalizedError {
    case missingName, outsideSupportedArea, invalidURL, missingKakaoKey
    var errorDescription: String? {
        switch self {
        case .missingName: return "목적지 이름을 확인해주세요."
        case .outsideSupportedArea: return "국내 목적지를 다시 선택해주세요."
        case .invalidURL: return "길 안내 연결 정보를 만들지 못했어요."
        case .missingKakaoKey: return "카카오내비 연결 설정을 준비 중이에요. 네이버지도를 이용해주세요."
        }
    }
}

struct NavigationDestination: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    init(id: UUID = UUID(), name: String, address: String, latitude: Double, longitude: Double) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw DestinationError.missingName }
        // Intersection with Naver's documented domestic navigation coordinate bounds.
        guard latitude.isFinite, longitude.isFinite,
              (31.43...44.35).contains(latitude), (122.37...132.00).contains(longitude) else {
            throw DestinationError.outsideSupportedArea
        }
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(UUID.self, forKey: .id),
                      name: c.decode(String.self, forKey: .name),
                      address: c.decode(String.self, forKey: .address),
                      latitude: c.decode(Double.self, forKey: .latitude),
                      longitude: c.decode(Double.self, forKey: .longitude))
    }
}

enum DeliveryStop: String, CaseIterable, Codable, Identifiable {
    case pickup, dropoff
    var id: Self { self }
    var title: String { self == .pickup ? "픽업지" : "도착지" }
    var icon: String { self == .pickup ? "shippingbox" : "mappin.and.ellipse" }
}

struct NavigationDraft: Codable, Equatable {
    var pickup: NavigationDestination?
    var dropoff: NavigationDestination?
    var selectedStop: DeliveryStop = .pickup
    var selectedDestination: NavigationDestination? { destination(for: selectedStop) }
    func destination(for stop: DeliveryStop) -> NavigationDestination? {
        stop == .pickup ? pickup : dropoff
    }
    mutating func set(_ destination: NavigationDestination?, for stop: DeliveryStop) {
        switch stop {
        case .pickup: pickup = destination
        case .dropoff: dropoff = destination
        }
    }
    // No order status exists here. An app launch/return cannot complete a delivery.
}

enum NavigationProvider: String, CaseIterable, Identifiable {
    case kakao, naver
    var id: Self { self }
    var title: String { self == .kakao ? "카카오내비" : "네이버지도" }
}

enum NaverNavigationURL {
    static func make(destination: NavigationDestination, bundleIdentifier: String) throws -> URL {
        guard !bundleIdentifier.isEmpty else { throw DestinationError.invalidURL }
        var url = URLComponents()
        url.scheme = "nmap"
        url.host = "navigation"
        url.queryItems = [
            URLQueryItem(name: "dlat", value: String(destination.latitude)),
            URLQueryItem(name: "dlng", value: String(destination.longitude)),
            URLQueryItem(name: "dname", value: destination.name),
            URLQueryItem(name: "appname", value: bundleIdentifier)
        ]
        // Preserve literal '+' even in receivers that parse queries as form data.
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let result = url.url else { throw DestinationError.invalidURL }
        return result
    }
}

enum AppConfiguration {
    static func usableKakaoKey(_ raw: String?) -> String? {
        guard let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              key.range(of: "^[0-9a-fA-F]{32}$", options: .regularExpression) != nil else { return nil }
        return key
    }
    static var kakaoKey: String? {
        usableKakaoKey(Bundle.main.object(forInfoDictionaryKey: "KakaoNativeAppKey") as? String)
    }
}
