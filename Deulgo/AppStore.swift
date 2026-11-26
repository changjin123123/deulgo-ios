import Foundation
import Combine

@MainActor final class DeulgoStore: ObservableObject {
    @Published private(set) var data = DeulgoData()
    @Published var storageError: String?
    private let fileURL: URL
    private var loaded = true

    nonisolated static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Deulgo/app-data-v1.json")
    }
    init(fileURL: URL = DeulgoStore.defaultURL) {
        self.fileURL = fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode(DeulgoData.self, from: Data(contentsOf: fileURL))
            guard saved.schemaVersion == 1 else { throw AppInputError("지원하지 않는 저장 형식이에요.") }
            data = saved
        } catch {
            loaded = false
            storageError = "저장 자료를 읽지 못했어요. 기존 자료를 덮어쓰지 않도록 저장을 중단했어요. 앱을 다시 열어주세요."
        }
    }
    func save(_ request: ShipmentDraft) throws {
        // This store keeps private drafts, not published delivery requests.
        try request.validate(requirePickup: false)
        var next = data
        var updated = request
        updated.updatedAt = Date()
        if let index = next.requests.firstIndex(where: { $0.id == updated.id }) { next.requests[index] = updated }
        else { next.requests.insert(updated, at: 0) }
        try commit(next)
    }
    func deleteRequest(_ id: UUID) throws { var next = data; next.requests.removeAll { $0.id == id }; try commit(next) }
    func save(_ vehicle: VehicleProfile) throws {
        try vehicle.validate()
        var next = data
        if let index = next.vehicles.firstIndex(where: { $0.id == vehicle.id }) { next.vehicles[index] = vehicle }
        else { next.vehicles.append(vehicle) }
        try commit(next)
    }
    func deleteVehicle(_ id: UUID) throws { var next = data; next.vehicles.removeAll { $0.id == id }; try commit(next) }
    func saveAddress(_ address: DeliveryAddress, label: String) throws {
        guard !address.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppInputError("주소를 먼저 선택해주세요.") }
        var next = data
        if !next.addresses.contains(where: { $0.address == address }) {
            guard next.addresses.count < 30 else { throw AppInputError("주소는 최대 30개까지 저장할 수 있어요.") }
            next.addresses.append(SavedAddress(label: label.isEmpty ? address.line : label, address: address))
        }
        try commit(next)
    }
    func deleteAddress(_ id: UUID) throws { var next = data; next.addresses.removeAll { $0.id == id }; try commit(next) }
    private func commit(_ next: DeulgoData) throws {
        guard loaded else { throw AppInputError(storageError ?? "저장 자료를 확인해주세요.") }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var protectedDirectory = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try protectedDirectory.setResourceValues(values)
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtection])
            data = next
            storageError = nil
        } catch {
            storageError = "기기에 저장하지 못했어요. 저장 공간을 확인한 뒤 다시 시도해주세요."
            throw AppInputError(storageError!)
        }
    }
}
