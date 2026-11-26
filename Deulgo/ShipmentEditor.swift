import SwiftUI

struct NewShipmentView: View {
    let onSaved: () -> Void
    @State private var formID = UUID()
    var body: some View {
        ShipmentEditor(initial: ShipmentDraft(), editing: false) { formID = UUID(); onSaved() }.id(formID)
    }
}

struct ShipmentEditor: View {
    @EnvironmentObject private var store: DeulgoStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ShipmentDraft
    @State private var step = 0
    @State private var pasted = ""
    @State private var showDimensions = false
    @State private var overwrite = false
    @State private var message: AppMessage?
    @StateObject private var importer = ListingImporter()
    private let editing: Bool
    private let onSaved: () -> Void

    init(initial: ShipmentDraft, editing: Bool, onSaved: @escaping () -> Void) {
        _draft = State(initialValue: initial)
        self.editing = editing
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        ForEach(Array(["물품", "주소", "확인"].enumerated()), id: \.offset) { index, title in
                            Label(title, systemImage: index < step ? "checkmark.circle.fill" : "\(index + 1).circle.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(index <= step ? DeulgoStyle.green : .secondary)
                            if index < 2 { Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary); Spacer() }
                        }
                    }.padding(.vertical, 6)
                }
                if step == 0 { itemSections }
                if step == 1 { addressSections }
                if step == 2 { reviewSections }
            }
            .navigationTitle(editing ? "요청 수정" : "물건 보내기")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    if step > 0 { Button("이전") { step -= 1 }.padding(.horizontal, 12) }
                    PrimaryAction(title: step == 2 ? "요청 내용 저장" : "다음", icon: step == 2 ? "checkmark" : "arrow.right", action: advance)
                }.padding(.horizontal, 20).padding(.vertical, 10).background(.regularMaterial)
            }
            .toolbar {
                if editing { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("입력 완료") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .appMessage($message)
            .confirmationDialog("현재 물품 정보를 불러온 내용으로 바꿀까요?", isPresented: $overwrite, titleVisibility: .visible) {
                Button("정보 적용") { applyPreview() }
                Button("취소", role: .cancel) {}
            }
            .onChange(of: draft.link) { _, _ in importer.reset() }
            .onDisappear { importer.reset() }
        }
    }

    @ViewBuilder private var itemSections: some View {
        Section("중고거래 링크 · 선택") {
            TextField("당근·번개장터·중고나라 링크", text: $draft.link, axis: .vertical)
                .lineLimit(1...2).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button { Task { await importer.load(draft.link) } } label: {
                HStack { Text(importer.busy ? "불러오는 중…" : "정보 불러오기"); Spacer(); if importer.busy { ProgressView() } else { Image(systemName: "arrow.down.doc") } }
            }.disabled(importer.busy || draft.link.isEmpty)
            if let link = try? ListingLink.parse(draft.link) { Link("\(link.platform) 원문 열기", destination: link.url) }
            if let error = importer.error { Text(error).font(.caption).foregroundStyle(.secondary) }
            if let preview = importer.preview {
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let data = preview.imageData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
                        else { Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary) }
                    }.frame(width: 60, height: 60).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    Text(preview.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                }
                if !preview.description.isEmpty {
                    DisclosureGroup("상품 설명 보기") { Text(preview.description).font(.caption).foregroundStyle(.secondary) }
                }
                if let dimensions = preview.dimensions {
                    Text("치수: \(dimensions.width ?? 0, specifier: "%g") × \(dimensions.depth ?? 0, specifier: "%g") × \(dimensions.height ?? 0, specifier: "%g") cm").font(.caption)
                }
                Button("물품 정보 적용") {
                    if !draft.item.isEmpty || draft.dimensions != ItemDimensions() { overwrite = true }
                    else { applyPreview() }
                }
            }
            DisclosureGroup("불러오기 어려우면 내용 붙여넣기") {
                TextField("상품명과 필요한 설명을 붙여넣어주세요", text: $pasted, axis: .vertical).lineLimit(3...6)
                Button("붙여넣은 내용 확인") { importer.usePasted(pasted) }.disabled(pasted.isEmpty)
            }
        }
        Section {
            TextField("예: 접이식 테이블", text: $draft.item).accessibilityLabel("물품 이름")
            Stepper("수량 \(draft.count)개", value: $draft.count, in: 1...10)
        } header: { Text("무엇을 보내나요?") }
        Section("포장과 크기") {
            Picker("포장 상태", selection: $draft.packaging) {
                ForEach(["포장할 예정이에요", "포장했어요", "그대로 운반해요", "분해했어요"], id: \.self) { Text($0) }
            }
            DisclosureGroup("크기·무게 입력 · 알고 있으면", isExpanded: $showDimensions) {
                OptionalNumberField(title: "가로", unit: "cm", value: $draft.dimensions.width)
                OptionalNumberField(title: "깊이", unit: "cm", value: $draft.dimensions.depth)
                OptionalNumberField(title: "높이", unit: "cm", value: $draft.dimensions.height)
                OptionalNumberField(title: "전체 무게", unit: "kg", value: $draft.weightKg)
                Text("포장 후 치수를 입력해주세요. 모르는 값은 비워둘 수 있어요.").font(.caption).foregroundStyle(.secondary)
            }
            Picker("운반 방향", selection: $draft.orientation) { ForEach(ItemOrientation.allCases) { Text($0.title).tag($0) } }
        }
    }

    @ViewBuilder private var addressSections: some View {
        AddressFormSection(stop: .pickup, address: $draft.pickup)
        AddressFormSection(stop: .dropoff, address: $draft.dropoff)
        Section("언제 받으면 좋을까요?") {
            Picker("희망 시간", selection: $draft.arrival) { ForEach(ArrivalPreference.allCases) { Text($0.title).tag($0) } }
            if draft.arrival == .scheduled { DatePicker("받고 싶은 시간", selection: $draft.desiredAt, in: Date()...) }
            Text("희망 시간은 운반자와 조율이 필요해요.").font(.caption).foregroundStyle(.secondary)
        }
        Section("운반할 때 필요한 것") {
            Toggle("계단으로 옮겨야 해요", isOn: $draft.stairs)
            Picker("작업 인원", selection: $draft.crew) { Text("1명").tag(1); Text("2명").tag(2) }
            DisclosureGroup("필요한 장비") { ToolSelection(selected: $draft.tools) }
            TextField("예: 깨지기 쉬워요, 문 앞에서 연락해주세요", text: $draft.note, axis: .vertical).lineLimit(2...5)
        }
    }

    @ViewBuilder private var reviewSections: some View {
        Section("보낼 물품") {
            LabeledContent("물품", value: draft.item)
            LabeledContent("수량", value: "\(draft.count)개")
            LabeledContent("포장", value: draft.packaging)
            LabeledContent("운반 방향", value: draft.orientation.title)
        }
        Section("이동 구간") {
            AddressSummary(title: "픽업지", address: draft.pickup)
            AddressSummary(title: "도착지", address: draft.dropoff)
            LabeledContent("희망 시간", value: draft.arrival == .scheduled ? draft.desiredAt.formatted(date: .abbreviated, time: .shortened) : draft.arrival.title)
        }
        Section("운반 조건") {
            LabeledContent("인원", value: "\(draft.crew)명")
            if draft.stairs { Label("계단 운반 필요", systemImage: "stairs") }
            if !draft.note.isEmpty { Text(draft.note).font(.subheadline) }
        }
        Section {
            Text("요청은 이 아이폰에 저장돼요. 아직 실제 배차나 결제가 진행되지는 않아요.").font(.subheadline)
            Text("배송비는 거리·운반 조건을 확인한 뒤 안내할 예정이에요.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func applyPreview() {
        guard let preview = importer.preview else { return }
        draft.item = preview.title
        if let dimensions = preview.dimensions { draft.dimensions = dimensions; showDimensions = true }
    }
    private func advance() {
        do {
            if step == 0 {
                guard !draft.item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppInputError("물품 이름을 입력해주세요.") }
                if !draft.link.isEmpty { draft.link = try ListingLink.parse(draft.link).url.absoluteString }
                step = 1
            } else if step == 1 { try draft.validate(); step = 2 }
            else { try store.save(draft); onSaved(); if editing { dismiss() } }
        } catch { message = AppMessage(title: "입력 내용을 확인해주세요", text: error.localizedDescription) }
    }
}

struct AddressFormSection: View {
    let stop: DeliveryStop
    @Binding var address: DeliveryAddress
    @EnvironmentObject private var store: DeulgoStore
    @State private var search = false
    @State private var saved = false
    @State private var message: AppMessage?
    var body: some View {
        Section(stop.title) {
            Button { search = true } label: { Label(address.line.isEmpty ? "주소 찾기" : "주소 다시 찾기", systemImage: "magnifyingglass") }
            TextField("기본 주소", text: Binding(get: { address.line }, set: { address.editLine($0) }), axis: .vertical).lineLimit(1...3)
            TextField("상세주소 · 동·호수 등", text: $address.detail)
            HStack {
                Button("저장 주소 선택") { saved = true }.disabled(store.data.addresses.isEmpty)
                Spacer()
                Button("주소 저장") {
                    do { try store.saveAddress(address, label: stop.title); message = AppMessage(title: "주소 저장", text: "이 아이폰에 주소를 저장했어요.") }
                    catch { message = AppMessage(title: "저장하지 못했어요", text: error.localizedDescription) }
                }.disabled(address.line.isEmpty)
            }.font(.caption)
            if !address.line.isEmpty && address.place == nil {
                Text("직접 입력한 주소예요. 길 안내를 사용하려면 주소 찾기에서 위치를 확인해주세요.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $search) { PlaceSearchView(stop: stop) { address.select($0) } }
        .sheet(isPresented: $saved) {
            NavigationStack {
                List(store.data.addresses) { entry in
                    Button { address = entry.address; saved = false } label: { AddressSummary(title: entry.label, address: entry.address) }.foregroundStyle(.primary)
                }.navigationTitle("저장한 주소").toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { saved = false } } }
            }
        }
        .appMessage($message)
    }
}

struct AddressBookView: View {
    @EnvironmentObject private var store: DeulgoStore
    @State private var message: AppMessage?
    var body: some View {
        List {
            if store.data.addresses.isEmpty { ContentUnavailableView("저장한 주소가 없어요", systemImage: "mappin", description: Text("보내기 화면에서 주소를 저장할 수 있어요.")) }
            ForEach(store.data.addresses) { entry in
                AddressSummary(title: entry.label, address: entry.address)
                    .swipeActions { Button("삭제", role: .destructive) {
                        do { try store.deleteAddress(entry.id) } catch { message = AppMessage(title: "삭제하지 못했어요", text: error.localizedDescription) }
                    } }
            }
        }.navigationTitle("저장한 주소").appMessage($message)
    }
}
