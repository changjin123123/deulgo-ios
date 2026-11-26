import SwiftUI

struct CarrierHomeView: View {
    @EnvironmentObject private var store: DeulgoStore
    @State private var adding = false
    @State private var editing: VehicleProfile?
    @State private var message: AppMessage?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("가는 길에, 들고.").font(.title2.bold())
                        Text("내 운반수단과 장비를 먼저 알려주세요.").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 10)
                }
                Section {
                    ForEach(store.data.vehicles) { vehicle in
                        Button { editing = vehicle } label: {
                            HStack(spacing: 14) {
                                Image(systemName: vehicle.kind.icon).font(.title2).foregroundStyle(DeulgoStyle.green)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(vehicle.title).font(.headline).foregroundStyle(.primary)
                                    Text("\(vehicle.year.map { "\($0)년형" } ?? "연식 몰라요") · \(vehicle.configuration)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }.padding(.vertical, 7)
                        }
                    }
                    Button { adding = true } label: { Label("운반수단 등록", systemImage: "plus.circle.fill") }
                } header: { Text("내 운반수단") } footer: { Text("등록 정보는 본인 입력 내용이며, 자격·보험 확인이 완료된 상태는 아니에요.") }
                Section("운반 준비") {
                    NavigationLink { CargoCatalogView() } label: { Label("차량 적재 용량 참고", systemImage: "shippingbox") }
                    NavigationLink { ComparisonView() } label: { Label("물품과 내 차량 비교", systemImage: "ruler") }
                }
                Section("운반 요청") {
                    ContentUnavailableView("실제 요청 연결 준비 중", systemImage: "tray", description: Text("현재는 차량 등록과 운반 조건 확인까지 사용할 수 있어요."))
                }
                Section("운반자 준수사항 · 검토안") {
                    Text("인수한 물품의 고의적인 가로채기·판매·은닉은 금지됩니다. 위반이 확인되면 영구 이용 제한과 손해배상 청구 대상이 되며, 범죄 혐의에 대해서는 수사기관 신고 및 증거 제출을 진행합니다.")
                        .font(.footnote)
                    Text("기존 시제품에 작성한 검토 문구이며, 출시 전 운영 정책·법률 검토가 필요합니다.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("운반하기")
                .sheet(isPresented: $adding) { VehicleEditor(initial: VehicleProfile()) }
                .sheet(item: $editing) { VehicleEditor(initial: $0) }
                .appMessage($message)
        }
    }
}

struct VehicleEditor: View {
    @EnvironmentObject private var store: DeulgoStore
    @Environment(\.dismiss) private var dismiss
    @State private var vehicle: VehicleProfile
    @State private var showModels = false
    @State private var showMeasures = false
    @State private var clearedMeasures = false
    @State private var confirmDelete = false
    @State private var message: AppMessage?
    private var years: [Int] { Array((2010...(Calendar.current.component(.year, from: Date()) + 1)).reversed()) }
    init(initial: VehicleProfile) { _vehicle = State(initialValue: initial) }
    var body: some View {
        NavigationStack {
            Form {
                Section("어떤 차로 운반하나요?") {
                    Picker("운반수단 종류", selection: $vehicle.kind) { ForEach(VehicleKind.allCases) { Text($0.title).tag($0) } }
                    Button { showModels = true } label: {
                        HStack { Text("차종·모델명").foregroundStyle(.primary); Spacer(); Text(vehicle.model.isEmpty ? "선택" : vehicle.title).lineLimit(1); Image(systemName: "chevron.down") }
                    }
                    Picker("연식", selection: Binding(get: { vehicle.year ?? 0 }, set: { vehicle.year = $0 == 0 ? nil : $0 })) {
                        Text("몰라요").tag(0)
                        ForEach(years, id: \.self) { Text("\($0)년형").tag($0) }
                    }
                }
                Section("어디에 실을까요?") {
                    Picker("적재 방식", selection: $vehicle.configuration) {
                        Text("아직 모르겠어요").tag("아직 모르겠어요")
                        ForEach(vehicle.kind.configurations, id: \.self) { Text($0) }
                    }
                }
                Section {
                    DisclosureGroup("크기 입력 · 직접 잰 값이 있으면", isExpanded: $showMeasures) {
                        if clearedMeasures { Text("차량이나 적재 방식이 바뀌어 이전 치수는 지웠어요. 현재 상태에서 잰 값만 입력해주세요.").font(.caption).foregroundStyle(.orange) }
                        if !vehicle.isOpenSpace {
                            OptionalNumberField(title: "입구 너비", unit: "cm", value: $vehicle.measurements.openingWidth)
                            OptionalNumberField(title: "입구 높이", unit: "cm", value: $vehicle.measurements.openingHeight)
                        }
                        OptionalNumberField(title: "공간 너비", unit: "cm", value: $vehicle.measurements.insideWidth)
                        OptionalNumberField(title: "공간 길이", unit: "cm", value: $vehicle.measurements.insideDepth)
                        OptionalNumberField(title: "공간 높이", unit: "cm", value: $vehicle.measurements.insideHeight)
                        Stepper("한쪽 여유 \(vehicle.margin, specifier: "%g")cm", value: $vehicle.margin, in: 0...20)
                    }
                } footer: { Text("치수는 몰라도 등록할 수 있어요. L 용량을 가로·세로·높이로 자동 환산하지 않아요.") }
                Section("운반 인원과 장비") {
                    Picker("작업 인원", selection: $vehicle.crew) { Text("1명").tag(1); Text("2명").tag(2) }
                    OptionalNumberField(title: "운반 가능한 무게", unit: "kg", value: $vehicle.capacityKg)
                    ToolSelection(selected: $vehicle.tools)
                }
                if vehicle.kind == .truck {
                    Section { Text("영업용 화물차는 유상운송 자격·보험 확인이 필요해요. 차량 등록만으로 실제 운반을 시작할 수는 없어요.").font(.caption) }
                }
                if store.data.vehicles.contains(where: { $0.id == vehicle.id }) {
                    Section { Button("운반수단 삭제", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle("운반수단 등록").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") {
                    do { try store.save(vehicle); dismiss() } catch { message = AppMessage(title: "입력을 확인해주세요", text: error.localizedDescription) }
                }.fontWeight(.semibold) }
            }
            .sheet(isPresented: $showModels) {
                VehicleModelPicker(kind: vehicle.kind) { brand, name in vehicle.brand = brand; vehicle.model = name }
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: vehicle.kind) { _, _ in vehicle.brand = ""; vehicle.model = ""; vehicle.configuration = "아직 모르겠어요" }
            .onChange(of: vehicle.scope) { _, _ in
                if vehicle.measurements.hasAny { vehicle.measurements = VehicleMeasurements(); clearedMeasures = true }
            }
            .confirmationDialog("이 운반수단을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    do { try store.deleteVehicle(vehicle.id); dismiss() } catch { message = AppMessage(title: "삭제하지 못했어요", text: error.localizedDescription) }
                }
            }
            .appMessage($message)
        }
    }
}

struct VehicleModelPicker: View {
    let kind: VehicleKind
    let select: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var directModel = ""
    var body: some View {
        NavigationStack {
            List {
                ForEach(ReferenceData.shared.models(kind: kind, query: query)) { row in
                    Button { select(row.brand, row.name); dismiss() } label: {
                        HStack { Text(row.name).foregroundStyle(.primary); Spacer(); Text(row.brand).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Section("목록에 없다면") {
                    TextField("차종·모델명 직접 입력", text: $directModel)
                    Button("이 모델 사용") { select("", directModel.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() }
                        .disabled(directModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .searchable(text: $query, prompt: "모델명·초성 검색 (예: ㅆㄴㅌ)")
            .navigationTitle("차종·모델명").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

struct CargoCatalogView: View {
    @State private var query = ""
    private var rows: [CapacityModel] {
        ReferenceData.shared.catalog.filter { query.isEmpty || ($0.brand + " " + $0.model).localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        List {
            Section {
                Text("2010년 이후 차량의 기존 조사 자료예요. 연식·시장·좌석 상태가 다르면 값이 달라져요. L 용량은 참고값이며 실제 적재 보장이 아니에요.").font(.caption).foregroundStyle(.secondary)
            }
            if rows.isEmpty { ContentUnavailableView("자료가 없어요", systemImage: "magnifyingglass", description: Text("다른 모델명으로 검색해주세요.")) }
            ForEach(rows) { model in
                NavigationLink { CapacityDetailView(model: model) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.brand + " " + model.model)
                        Text(model.variants.first?.capacities.map { $0.label + " " + liters($0.liters) + " L" }.joined(separator: " · ") ?? model.capacityStatus?.label ?? "출처 확인 필요")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }.navigationTitle("적재 용량 참고").searchable(text: $query, prompt: "브랜드·모델명")
    }
}

private func liters(_ values: [Double]) -> String { values.map { $0.formatted(.number.precision(.fractionLength(0...1))) }.joined(separator: "–") }

struct CapacityDetailView: View {
    let model: CapacityModel
    var body: some View {
        List {
            if let status = model.capacityStatus {
                Section { Text(status.label); Text(status.note).font(.caption); source(status.source) }
            }
            ForEach(Array(model.variants.enumerated()), id: \.offset) { _, variant in
                Section(variant.name) {
                    Text(variant.market).font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(variant.capacities.enumerated()), id: \.offset) { _, value in
                        LabeledContent(value.label, value: liters(value.liters) + " L" + (value.exceeds == true ? " 초과" : ""))
                    }
                    if let note = variant.note, !note.isEmpty { Text(note).font(.caption) }
                    source(variant.source)
                }
            }
            if !model.dimensions.isEmpty {
                Section {
                    DisclosureGroup("상세 치수 보기") {
                        ForEach(Array(model.dimensions.enumerated()), id: \.offset) { _, record in
                            Text(record.vehicle).font(.headline)
                            ForEach(Array(record.entries.enumerated()), id: \.offset) { _, entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.label + ": " + (["owner_approximate", "unit_conversion"].contains(entry.qualifier ?? "") ? "약 " : "") + liters(entry.mm) + " mm")
                                    if let condition = entry.condition, !condition.isEmpty { Text(condition).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                            if let note = record.note, !note.isEmpty { Text(note).font(.caption) }
                            source(record.source)
                        }
                    }
                }
            }
        }.navigationTitle(model.brand + " " + model.model).navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder private func source(_ source: ReferenceSource) -> some View {
        if let url = URL(string: source.url), url.scheme == "https" { Link("출처: " + source.title, destination: url).font(.caption) }
    }
}
