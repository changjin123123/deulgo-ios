import SwiftUI
import MapKit
import Combine

struct PlaceCandidate: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    var destination: NavigationDestination? {
        try? NavigationDestination(name: name, address: address,
                                   latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

@MainActor final class PlaceSearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [PlaceCandidate] = []
    @Published private(set) var isSearching = false
    @Published var message: String?
    private var request: MKLocalSearch?
    private var generation = UUID()

    func cancel() {
        generation = UUID()
        request?.cancel()
        request = nil
        isSearching = false
    }
    func queryChanged() { cancel(); results = []; message = nil }

    func search() async {
        cancel()
        results = []
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let token = generation
        isSearching = true
        message = nil
        let config = MKLocalSearch.Request()
        config.naturalLanguageQuery = text
        config.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 36.3, longitude: 127.8),
                                           span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6))
        let search = MKLocalSearch(request: config)
        request = search
        defer { if token == generation { isSearching = false; request = nil } }
        do {
            let response = try await search.start()
            guard token == generation else { return }
            results = response.mapItems.compactMap { item in
                let candidate = PlaceCandidate(name: item.name ?? item.placemark.title ?? text,
                                               address: item.placemark.title ?? "",
                                               coordinate: item.placemark.coordinate)
                return candidate.destination == nil ? nil : candidate
            }
            if results.isEmpty { message = "국내 검색 결과가 없어요. 도로명 주소나 건물명으로 다시 검색해주세요." }
        } catch {
            guard token == generation else { return }
            message = "위치를 찾지 못했어요. 인터넷 연결과 주소를 확인한 뒤 다시 시도해주세요."
        }
    }
}

struct PlaceSearchView: View {
    let stop: DeliveryStop
    let onSelect: (NavigationDestination) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PlaceSearchModel()
    @State private var selected: PlaceCandidate?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("도로명 주소 또는 건물명", text: $model.query)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit { Task { await model.search() } }
                        Button("검색") { Task { await model.search() } }
                            .disabled(model.isSearching || model.query.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: { Text("검색어를 Apple 지도에 보내 위치를 찾아요. 동·호수는 입력하지 않아도 돼요.") }
                if model.isSearching { ProgressView("위치를 찾고 있어요") }
                if let message = model.message { Text(message).foregroundStyle(.secondary) }
                if let selected, let destination = selected.destination {
                    Section("선택한 위치") {
                        Map(initialPosition: .region(MKCoordinateRegion(center: selected.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)))) {
                            Marker(selected.name, coordinate: selected.coordinate)
                        }
                        .frame(height: 210).id(selected.id)
                        Text(selected.name).font(.headline)
                        Text(selected.address).font(.subheadline).foregroundStyle(.secondary)
                        Button("이 위치를 \(stop.title)로 선택") { onSelect(destination); dismiss() }
                            .buttonStyle(.borderedProminent)
                    } footer: { Text("같은 이름의 장소가 있을 수 있어요. 주소와 지도 위치를 확인해주세요.") }
                }
                Section("검색 결과") {
                    ForEach(model.results) { result in
                        Button { selected = result } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(result.name).foregroundStyle(.primary)
                                Text(result.address).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("\(stop.title) 찾기").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .onChange(of: model.query) { _, _ in model.queryChanged(); selected = nil }
            .onDisappear { model.cancel() }
        }
    }
}
