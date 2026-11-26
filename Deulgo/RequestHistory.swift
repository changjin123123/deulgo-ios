import SwiftUI

struct RequestHistoryView: View {
    @EnvironmentObject private var store: DeulgoStore
    @State private var query = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if store.data.requests.isEmpty {
                        ContentUnavailableView("임시 보관한 요청이 없어요", systemImage: "shippingbox", description: Text("보내기에서 물품과 주소를 입력해보세요."))
                    }
                    ForEach(store.data.requests.filter { query.isEmpty || $0.item.localizedCaseInsensitiveContains(query) }) { request in
                        NavigationLink { RequestDetailView(requestID: request.id) } label: { RequestCard(request: request) }.buttonStyle(.plain)
                    }
                    LocalModeNote()
                }.padding(20)
            }.background(Color(.systemGroupedBackground)).navigationTitle("내 배송 내역")
                .searchable(text: $query, prompt: "물품 이름 검색")
        }
    }
}

struct RequestDetailView: View {
    let requestID: UUID
    @EnvironmentObject private var store: DeulgoStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ShipmentDraft?
    @State private var navigating: ShipmentDraft?
    @State private var deleting = false
    @State private var message: AppMessage?
    private var request: ShipmentDraft? { store.data.requests.first { $0.id == requestID } }
    var body: some View {
        List {
            if let request {
                Section {
                    Text(request.item).font(.title2.bold())
                    LabeledContent("상태", value: "임시 보관 · 아직 게시되지 않음")
                    if let count = request.count { LabeledContent("기존 입력 수량", value: "\(count)개") }
                    else { Text("물품 구성·수량은 판매자 확인 필요").font(.caption).foregroundStyle(.secondary) }
                    Text(request.packaging).font(.subheadline)
                }
                Section("이동 구간") {
                    AddressSummary(title: "픽업지", address: request.pickup, emptyText: "판매자에게 주소 확인 필요")
                    AddressSummary(title: "도착지", address: request.dropoff)
                    LabeledContent("희망 시간", value: request.arrival == .scheduled ? request.desiredAt.formatted(date: .abbreviated, time: .shortened) : request.arrival.title)
                    Button { navigating = request } label: { Label("길 안내", systemImage: "arrow.triangle.turn.up.right.diamond") }
                        .disabled(request.pickup.place == nil && request.dropoff.place == nil)
                    if request.pickup.place == nil || request.dropoff.place == nil { Text("주소 찾기에서 위치를 확인한 주소만 내비로 전달할 수 있어요.").font(.caption).foregroundStyle(.secondary) }
                }
                Section("운반 조건") {
                    LabeledContent("작업 인원", value: "\(request.crew)명")
                    LabeledContent("계단 운반", value: request.stairs ? "필요" : "미선택")
                    if !request.note.isEmpty { Text(request.note) }
                    NavigationLink("내 차량과 비교") { ComparisonView(initialRequestID: request.id) }
                }
                if let link = try? ListingLink.parse(request.link) { Section { Link("거래글 원문 열기", destination: link.url) } }
                Section {
                    Button("요청 수정") { editing = request }
                    Button("요청 삭제", role: .destructive) { deleting = true }
                }
            } else { Text("이 요청을 찾을 수 없어요.") }
        }
        .navigationTitle("요청 상세").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { ShipmentEditor(initial: $0, editing: true, onSaved: {}) }
        .sheet(item: $navigating) { request in
            DeliveryNavigationView(pickup: request.pickup.place, dropoff: request.dropoff.place)
        }
        .confirmationDialog("저장한 요청을 삭제할까요?", isPresented: $deleting, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                do { try store.deleteRequest(requestID); dismiss() } catch { message = AppMessage(title: "삭제하지 못했어요", text: error.localizedDescription) }
            }
        }.appMessage($message)
    }
}

struct ComparisonView: View {
    @EnvironmentObject private var store: DeulgoStore
    @State private var requestID: UUID?
    @State private var vehicleID: UUID?
    init(initialRequestID: UUID? = nil) { _requestID = State(initialValue: initialRequestID) }
    private var request: ShipmentDraft? { store.data.requests.first { $0.id == requestID } }
    private var vehicle: VehicleProfile? { store.data.vehicles.first { $0.id == vehicleID } }
    var body: some View {
        Form {
            Section("비교할 정보") {
                Picker("물품 요청", selection: $requestID) {
                    Text("선택해주세요").tag(nil as UUID?)
                    ForEach(store.data.requests) { Text($0.item).tag(Optional($0.id)) }
                }
                Picker("운반수단", selection: $vehicleID) {
                    Text("선택해주세요").tag(nil as UUID?)
                    ForEach(store.data.vehicles) { Text($0.title).tag(Optional($0.id)) }
                }
            }
            if let request, let vehicle {
                Section("입력한 조건 비교") {
                    comparison("치수", ReferenceData.shared.fit(request: request, vehicle: vehicle))
                    if let weight = request.weightKg, let capacity = vehicle.capacityKg {
                        comparison("무게", weight <= capacity ? "입력한 운반 가능 무게 이내예요. 차량 허용 하중과 고정 상태는 별도로 확인해주세요." : "입력한 운반 가능 무게를 초과해요.")
                    } else { comparison("무게", "물품 무게 또는 운반 가능한 무게를 확인해야 해요.") }
                    comparison("작업 인원", vehicle.crew >= request.crew ? "입력한 인원 조건은 맞아요." : "작업 인원이 부족해요.")
                    let missing = request.tools.subtracting(vehicle.tools)
                    comparison("장비", missing.isEmpty ? "요청한 장비는 등록되어 있어요. 실제 지참 여부는 확인해주세요." : "추가 장비: " + TransportTools.all.filter { missing.contains($0.0) }.map { $0.1 }.joined(separator: ", "))
                    if request.stairs { comparison("계단", "현장 계단과 작업 가능 여부를 사전에 확인해주세요.") }
                    if vehicle.kind == .truck { comparison("자격", "영업용 화물차 유상운송 자격·보험 확인 전이에요.") }
                }
                Section { Text("문을 통과시키는 회전 동작, 여러 물품의 동시 적재, 실제 장비·하중·보험은 확인되지 않았어요. 비교 결과는 배차나 적재 보장이 아니에요.").font(.caption).foregroundStyle(.secondary) }
            } else {
                Section { Text("저장한 물품 요청과 운반수단을 선택해주세요.").foregroundStyle(.secondary) }
            }
        }.navigationTitle("운반 조건 비교").navigationBarTitleDisplayMode(.inline)
    }
    private func comparison(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical, 4)
    }
}
