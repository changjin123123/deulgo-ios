import Foundation
import Combine

@MainActor final class DraftStore: ObservableObject {
    @Published private(set) var draft = NavigationDraft()
    @Published var storageMessage: String?
    private let fileURL: URL?

    init(draft: NavigationDraft) {
        self.fileURL = nil
        self.draft = draft
    }

    init(fileURL: URL? = DraftStore.defaultFileURL) {
        self.fileURL = fileURL
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            draft = try JSONDecoder().decode(NavigationDraft.self, from: Data(contentsOf: fileURL))
        } catch {
            storageMessage = "저장된 위치를 읽지 못했어요. 픽업지와 도착지를 다시 선택해주세요."
        }
    }

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Deulgo/navigation-draft.json")
    }

    func select(_ stop: DeliveryStop) { draft.selectedStop = stop; save() }
    func set(_ destination: NavigationDestination?, for stop: DeliveryStop) {
        draft.set(destination, for: stop)
        save()
    }
    func clear() {
        draft = NavigationDraft()
        storageMessage = nil
        guard let fileURL else { return }
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
        } catch { storageMessage = "기기에 저장된 위치를 삭제하지 못했어요. 다시 시도해주세요." }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excludedURL = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excludedURL.setResourceValues(values)
            try JSONEncoder().encode(draft).write(to: fileURL, options: [.atomic, .completeFileProtection])
            storageMessage = nil
        } catch { storageMessage = "위치를 기기에 저장하지 못했어요. 앱을 닫으면 다시 선택해야 할 수 있어요." }
    }
}
