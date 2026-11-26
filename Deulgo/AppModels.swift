import Foundation

struct ItemDimensions: Codable, Equatable {
    var width: Double?
    var depth: Double?
    var height: Double?
}

enum ItemOrientation: String, Codable, CaseIterable, Identifiable {
    case any, upright, fixed
    var id: Self { self }
    var title: String {
        switch self { case .any: return "눕혀도 돼요"; case .upright: return "세워서 운반해요"; case .fixed: return "현재 방향 그대로" }
    }
}

enum ArrivalPreference: String, Codable, CaseIterable, Identifiable {
    case flexible, today, scheduled
    var id: Self { self }
    var title: String {
        switch self { case .flexible: return "시간 협의 가능"; case .today: return "오늘 중"; case .scheduled: return "희망 시간 선택" }
    }
}

struct DeliveryAddress: Codable, Equatable {
    var line = ""
    var detail = ""
    var place: NavigationDestination?
    var display: String { [line, detail].filter { !$0.isEmpty }.joined(separator: " ") }
    mutating func select(_ destination: NavigationDestination) {
        place = destination
        line = destination.address.isEmpty ? destination.name : destination.address
    }
    mutating func editLine(_ value: String) { line = value; place = nil }
}

struct ShipmentDraft: Codable, Identifiable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var updatedAt = Date()
    var item = ""
    var count = 1
    var link = ""
    var dimensions = ItemDimensions()
    var weightKg: Double?
    var orientation: ItemOrientation = .any
    var packaging = "포장할 예정이에요"
    var pickup = DeliveryAddress()
    var dropoff = DeliveryAddress()
    var arrival: ArrivalPreference = .flexible
    var desiredAt = Date().addingTimeInterval(3600)
    var crew = 1
    var stairs = false
    var tools: Set<String> = []
    var note = ""

    func validate(now: Date = Date()) throws {
        guard !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppInputError("물품 이름을 입력해주세요.") }
        guard (1...10).contains(count) else { throw AppInputError("물품 수량은 1~10개로 입력해주세요.") }
        guard !pickup.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !dropoff.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppInputError("픽업지와 도착지를 입력해주세요.") }
        for n in [dimensions.width, dimensions.depth, dimensions.height] {
            if let n, !n.isFinite || n <= 0 || n > 1000 { throw AppInputError("물품 치수는 0보다 크고 1,000cm 이하로 입력해주세요.") }
        }
        if let weightKg, !weightKg.isFinite || weightKg <= 0 || weightKg > 10000 { throw AppInputError("물품 무게를 확인해주세요.") }
        if arrival == .scheduled && desiredAt <= now { throw AppInputError("희망 시간을 현재보다 늦게 선택해주세요.") }
        if !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { _ = try ListingLink.parse(link) }
        guard item.count <= 100, note.count <= 1000 else { throw AppInputError("물품 이름은 100자, 메모는 1,000자 이내로 입력해주세요.") }
    }
}

enum VehicleKind: String, Codable, CaseIterable, Identifiable {
    case car, bike, truck
    var id: Self { self }
    var title: String { self == .car ? "승용차" : self == .bike ? "오토바이" : "영업용 화물차" }
    var icon: String { self == .car ? "car.fill" : self == .bike ? "motorcycle.fill" : "truck.box.fill" }
    var configurations: [String] {
        switch self {
        case .car: return ["트렁크만 써요", "뒷좌석 일부 접었어요", "뒷좌석 전부 접었어요", "뒷좌석에 실어요", "앞 트렁크에 실어요"]
        case .bike: return ["배송함·탑박스에 실어요", "안장·짐받이에 고정해요"]
        case .truck: return ["개방형 적재함", "탑차·덮개 있는 적재함"]
        }
    }
}

struct VehicleMeasurements: Codable, Equatable {
    var openingWidth: Double?
    var openingHeight: Double?
    var insideWidth: Double?
    var insideDepth: Double?
    var insideHeight: Double?
    var hasAny: Bool { [openingWidth, openingHeight, insideWidth, insideDepth, insideHeight].contains { $0 != nil } }
}

struct VehicleProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: VehicleKind = .car
    var brand = ""
    var model = ""
    var year: Int?
    var configuration = "아직 모르겠어요"
    var capacityKg: Double?
    var crew = 1
    var tools: Set<String> = []
    var measurements = VehicleMeasurements()
    var margin: Double = 2
    var title: String { model.isEmpty ? kind.title : [brand, model].filter { !$0.isEmpty }.joined(separator: " ") }
    var scope: String { [kind.rawValue, brand, model, year.map(String.init) ?? "", configuration].joined(separator: "|") }
    var isOpenSpace: Bool { ["안장·짐받이에 고정해요", "개방형 적재함"].contains(configuration) }
    func validate(currentYear: Int = Calendar.current.component(.year, from: Date())) throws {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppInputError("차종·모델명을 선택하거나 직접 입력해주세요.") }
        if let year, !(2010...(currentYear + 1)).contains(year) { throw AppInputError("연식은 2010년 이후로 선택해주세요. 모르면 ‘몰라요’를 선택할 수 있어요.") }
        if let capacityKg, !capacityKg.isFinite || capacityKg <= 0 || capacityKg > 10000 { throw AppInputError("운반 가능한 무게를 확인해주세요.") }
        for n in [measurements.openingWidth, measurements.openingHeight, measurements.insideWidth, measurements.insideDepth, measurements.insideHeight] {
            if let n, !n.isFinite || n <= 0 || n > 1000 { throw AppInputError("차량 치수는 0보다 크고 1,000cm 이하로 입력해주세요.") }
        }
        guard margin.isFinite, (0...20).contains(margin) else { throw AppInputError("한쪽 여유를 0~20cm로 입력해주세요.") }
    }
}

enum TransportTools {
    static let all = [("cart", "운반 카트"), ("straps", "고정끈"), ("blankets", "보호담요"), ("padding", "완충재"), ("handTools", "분해·조립 공구")]
}

struct SavedAddress: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var address: DeliveryAddress
}

struct DeulgoData: Codable, Equatable {
    var schemaVersion = 1
    var requests: [ShipmentDraft] = []
    var vehicles: [VehicleProfile] = []
    var addresses: [SavedAddress] = []
}

struct AppInputError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct AppMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}
