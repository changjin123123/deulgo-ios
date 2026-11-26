import Foundation
import JavaScriptCore

struct VehicleModelChoice: Identifiable {
    let brand: String
    let name: String
    var id: String { brand + ":" + name }
}

struct CapacityCatalog: Decodable {
    let models: [CapacityModel]
}
struct CapacityModel: Decodable, Identifiable {
    let id: String
    let brand: String
    let model: String
    let variants: [CapacityVariant]
    let dimensions: [DimensionRecord]
    let capacityStatus: CapacityStatus?
}
struct CapacityStatus: Decodable { let label: String; let note: String; let source: ReferenceSource }
struct ReferenceSource: Decodable { let url: String; let title: String }
struct CapacityVariant: Decodable {
    let name: String
    let market: String
    let source: ReferenceSource
    let capacities: [CapacityValue]
    let note: String?
}
struct CapacityValue: Decodable { let label: String; let liters: [Double]; let exceeds: Bool? }
struct DimensionRecord: Decodable {
    let vehicle: String
    let source: ReferenceSource
    let entries: [DimensionValue]
    let note: String?
}
struct DimensionValue: Decodable { let label: String; let mm: [Double]; let condition: String?; let qualifier: String? }

@MainActor final class ReferenceData {
    static let shared = ReferenceData()
    private let context: JSContext?
    let catalog: [CapacityModel]
    let unavailable: Bool

    init(bundle: Bundle = .main) {
        context = JSContext()
        var failed = false
        for name in ["vehicle-models", "listing-rules", "fit-rules"] {
            guard let url = bundle.url(forResource: name, withExtension: "js"), let source = try? String(contentsOf: url, encoding: .utf8) else { failed = true; continue }
            context?.evaluateScript(source)
            if context?.exception != nil { failed = true; context?.exception = nil }
        }
        if let url = bundle.url(forResource: "vehicle-cargo-2010", withExtension: "json"),
           let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(CapacityCatalog.self, from: data) {
            catalog = decoded.models
        } else { catalog = []; failed = true }
        unavailable = failed || context == nil
    }
    func models(kind: VehicleKind, query: String) -> [VehicleModelChoice] {
        let imports = catalog.map { ["brand": $0.brand, "name": $0.model] }
        guard let result = context?.objectForKeyedSubscript("nativeVehicleModels")?.call(withArguments: [kind.rawValue, query, imports]),
              let rows = result.toArray() as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let brand = row["brand"] as? String, let name = row["name"] as? String else { return nil }
            return VehicleModelChoice(brand: brand, name: name)
        }
    }
    func pastedListing(_ text: String) -> ListingPreview? {
        guard let value = context?.objectForKeyedSubscript("parseSharedText")?.call(withArguments: [text]),
              let row = value.toDictionary() as? [String: Any], let title = row["title"] as? String,
              !title.isEmpty else { return nil }
        let dims = row["dimensions"] as? [String: Double]
        return ListingPreview(title: title, description: row["description"] as? String ?? "", imageData: nil,
                              dimensions: dims.map { ItemDimensions(width: $0["w"], depth: $0["d"], height: $0["h"]) })
    }
    func fit(request: ShipmentDraft, vehicle: VehicleProfile) -> String {
        guard let count = request.count else { return "물품 구성과 수량을 확인해야 적재 조건을 비교할 수 있어요." }
        guard request.orientation != .unknown else { return "물품을 눕히거나 세워도 되는지 확인해주세요." }
        if vehicle.isOpenSpace { return "개방형 적재공간은 돌출과 고정 상태를 직접 확인해주세요." }
        let m = vehicle.measurements
        let number: (Double?) -> Any = { $0.map { $0 as Any } ?? NSNull() }
        let input: [String: Any] = [
            "vehicle": ["openingWidth": number(m.openingWidth), "openingHeight": number(m.openingHeight),
                        "insideWidth": number(m.insideWidth), "insideDepth": number(m.insideDepth), "insideHeight": number(m.insideHeight)],
            "pieces": [["label": request.item, "w": number(request.dimensions.width), "d": number(request.dimensions.depth),
                        "h": number(request.dimensions.height), "count": count, "orientation": request.orientation.rawValue]],
            "margin": vehicle.margin
        ]
        let result = context?.objectForKeyedSubscript("FitRules")?.objectForKeyedSubscript("compare")?.call(withArguments: [input])
        let status = result?.objectForKeyedSubscript("status")?.toString()
        switch status {
        case "candidate": return "입력한 치수 조건은 맞아요. 실제 적재 여부는 확인이 필요해요."
        case "separate": return "한 개씩 치수 조건은 맞아요. 여러 개를 동시에 실을 수 있는지는 확인이 필요해요."
        case "exceeds": return "입력한 치수 기준으로 공간을 초과해요."
        default: return "치수가 부족해 비교할 수 없어요. L 용량만으로 적재 가능 여부를 확정하지 않아요."
        }
    }
}
