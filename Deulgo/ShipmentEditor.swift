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
    @State private var showItemDetails = false
    @State private var autofill = ListingAutofill()
    @State private var autofillNotice: String?
    @State private var message: AppMessage?
    @State private var keyboardVisible = false
    @FocusState private var focusedInput: ItemInput?
    @StateObject private var importer = ListingImporter()
    private enum ItemInput: Hashable { case link, item, pasted }
    private let editing: Bool
    private let onSaved: () -> Void

    init(initial: ShipmentDraft, editing: Bool, onSaved: @escaping () -> Void) {
        _draft = State(initialValue: initial)
        self.editing = editing
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            editorContent
            .navigationTitle(editing ? "요청 수정" : "물건 보내기")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !keyboardVisible { VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        if step > 0 { Button("이전") { step -= 1 }.padding(.horizontal, 12) }
                        if step == 2 {
                            // Enable only when actual publication and carrier acceptance exist.
                            PrimaryAction(title: "운반 요청 올리기", icon: "paperplane", action: {})
                                .disabled(true).opacity(0.45)
                                .accessibilityHint("운반자에게 요청을 공개하는 기능은 준비 중이에요")
                        } else { PrimaryAction(title: "다음", action: advance).accessibilityIdentifier("shipment.next") }
                    }
                    if step == 2 {
                        Text("운반자 공개 준비 중 · 아직 요청이 올라가지 않아요").font(.caption).foregroundStyle(.secondary)
                        Button(editing ? "임시 보관 내용 수정" : "작성 내용 임시 보관", action: keepDraft).font(.subheadline)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 10).background(.regularMaterial) }
            }
            .toolbar {
                if editing { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
                ToolbarItem(placement: .topBarTrailing) {
                    if keyboardVisible {
                        Button(action: dismissKeyboard) { Image(systemName: "keyboard.chevron.compact.down").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("키보드 닫기").accessibilityIdentifier("shipment.dismissKeyboard")
                    }
                }
            }
            .toolbar(keyboardVisible ? .hidden : .visible, for: .tabBar)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in keyboardVisible = false }
            .appMessage($message)
            .task(id: draft.link) {
                let input = draft.link
                guard (try? ListingLink.parse(input)) != nil else { return }
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                guard !Task.isCancelled else { return }
                await importer.load(input)
            }
            .onChange(of: importer.preview?.id) { _, id in if id != nil { applyPreview() } }
            .onDisappear { importer.reset(); dismissKeyboard(); keyboardVisible = false }
        }
    }

    @ViewBuilder private var editorContent: some View {
        if step == 0 {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        progressHeader.padding(.top, 22).padding(.bottom, 36)
                        itemSections
                        Color.clear.frame(minHeight: 50).contentShape(Rectangle()).onTapGesture(perform: dismissKeyboard)
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.immediately)
                .background { Color(.systemBackground).contentShape(Rectangle()).onTapGesture(perform: dismissKeyboard) }
                .accessibilityIdentifier("shipment.itemScroll")
            }
        } else {
            Form {
                Section { progressHeader }
                if step == 1 { addressSections }
                if step == 2 { reviewSections }
            }.scrollDismissesKeyboard(.immediately)
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 14) {
            Spacer()
            ForEach(Array(["물품", "주소", "확인"].enumerated()), id: \.offset) { index, title in
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(index <= step ? DeulgoStyle.green : .secondary)
                if index < 2 { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
            }
            Spacer()
        }.padding(.vertical, 6).contentShape(Rectangle()).onTapGesture(perform: dismissKeyboard)
    }

    @ViewBuilder private var itemSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("중고거래 링크").font(.title3.weight(.semibold))
                Text("· 선택").font(.subheadline).foregroundStyle(.secondary)
            }.padding(.bottom, 4).onTapGesture(perform: dismissKeyboard)
            TextField("당근·번개장터·중고나라 링크", text: Binding(get: { draft.link }, set: changeLink), prompt: Text("당근·번개장터·중고나라 링크").foregroundColor(.primary.opacity(0.6)), axis: .vertical)
                .lineLimit(1...2).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focusedInput, equals: .link)
                .padding(.horizontal, 14).padding(.vertical, 16).frame(minHeight: 54)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(focusedInput == .link ? DeulgoStyle.green : Color(.systemGray), lineWidth: 1))
                .accessibilityLabel("중고거래 링크").accessibilityIdentifier("shipment.link")
            Text("링크를 넣으면 물품명이 자동 입력돼요.").font(.subheadline).foregroundStyle(Color.primary.opacity(0.6))
                .onTapGesture(perform: dismissKeyboard)
            if importer.busy {
                HStack { Text("물품 정보 불러오는 중…"); Spacer(); ProgressView() }.font(.footnote)
            }
            if let error = importer.error {
                VStack(alignment: .leading, spacing: 12) {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    if (try? ListingLink.parse(draft.link)) != nil {
                        Button("정보 다시 불러오기") { Task { await importer.load(draft.link) } }.font(.subheadline)
                    }
                    DisclosureGroup("내용을 복사해서 입력하기") {
                        TextField("상품명과 필요한 설명", text: $pasted, axis: .vertical).lineLimit(3...6).focused($focusedInput, equals: .pasted)
                        Button("붙여넣은 내용 확인") { importer.usePasted(pasted); dismissKeyboard() }.disabled(pasted.isEmpty)
                    }.font(.subheadline)
                }.padding(.top, 4)
            }
            if let preview = importer.preview {
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let data = preview.imageData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
                        else { Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary) }
                    }.frame(width: 60, height: 60).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    Text(preview.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                }
                if let link = try? ListingLink.parse(draft.link) { Link("\(link.platform) 원문 열기", destination: link.url).font(.footnote) }
                if !preview.description.isEmpty {
                    DisclosureGroup("상품 설명 보기") { Text(preview.description).font(.caption).foregroundStyle(.secondary) }
                }
                if let dimensions = preview.dimensions {
                    Text("치수: \(dimensions.width ?? 0, specifier: "%g") × \(dimensions.depth ?? 0, specifier: "%g") × \(dimensions.height ?? 0, specifier: "%g") cm").font(.caption)
                }
            }
            if let autofillNotice { Text(autofillNotice).font(.caption).foregroundStyle(.secondary) }
        }
        VStack(alignment: .leading, spacing: 12) {
            Text("무엇을 보낼까요?").font(.title2.bold()).onTapGesture(perform: dismissKeyboard)
            Text("링크가 없으면 물품명을 직접 적어주세요.").font(.subheadline).foregroundStyle(Color.primary.opacity(0.6)).onTapGesture(perform: dismissKeyboard)
            TextField("예: 접이식 테이블", text: $draft.item, prompt: Text("예: 접이식 테이블").foregroundColor(.primary.opacity(0.6)))
                .focused($focusedInput, equals: .item).submitLabel(.done).onSubmit(dismissKeyboard)
                .font(.body).padding(.vertical, 16)
                .overlay(alignment: .bottom) { Rectangle().fill(Color(.systemGray)).frame(height: 1) }
                .accessibilityLabel("물품 이름").accessibilityIdentifier("shipment.item")
        }.padding(.top, 44)
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showItemDetails) {
                VStack(alignment: .leading, spacing: 16) {
                Picker("포장 상태", selection: Binding(get: { draft.packagingDisplay }, set: { draft.packaging = $0 })) {
                    ForEach(["확인 필요", "포장할 예정이에요", "포장했어요", "그대로 운반해요", "분해했어요"], id: \.self) { Text($0) }
                }
                OptionalNumberField(title: "가로", unit: "cm", value: $draft.dimensions.width)
                OptionalNumberField(title: "깊이", unit: "cm", value: $draft.dimensions.depth)
                OptionalNumberField(title: "높이", unit: "cm", value: $draft.dimensions.height)
                OptionalNumberField(title: "전체 무게", unit: "kg", value: $draft.weightKg)
                Picker("운반 방향", selection: $draft.orientation) { ForEach(ItemOrientation.allCases) { Text($0.title).tag($0) } }
                Text("알고 있는 정보만 입력해주세요. 다른 사람의 물건이라면 물건을 건네줄 분에게 확인해주세요.").font(.caption).foregroundStyle(.secondary)
                Text("여러 물품은 물품명이나 요청 메모에 적어주세요. 구성·수량·포장·크기는 운반 전에 확인해야 해요.").font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 16)
            } label: {
                Text("물품 상세").font(.headline) + Text(" · 선택").font(.subheadline).foregroundColor(.secondary)
            }
        }.padding(.top, 36).padding(.bottom, 24)
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
            if let count = draft.count { LabeledContent("기존 입력 수량", value: "\(count)개") }
            else { Text("물품 구성·수량 확인 필요").font(.caption).foregroundStyle(.secondary) }
            LabeledContent("포장", value: draft.packagingDisplay)
            LabeledContent("운반 방향", value: draft.orientation.title)
        }
        Section("이동 구간") {
            AddressSummary(title: "물건 있는 곳 · 픽업지", address: draft.pickup, emptyText: "픽업 주소 확인 필요")
            AddressSummary(title: "받는 곳 · 도착지", address: draft.dropoff)
            LabeledContent("희망 시간", value: draft.arrival == .scheduled ? draft.desiredAt.formatted(date: .abbreviated, time: .shortened) : draft.arrival.title)
        }
        Section("운반 조건") {
            LabeledContent("인원", value: "\(draft.crew)명")
            if draft.stairs { Label("계단 운반 필요", systemImage: "stairs") }
            if !draft.note.isEmpty { Text(draft.note).font(.subheadline) }
        }
        Section {
            Text("요청을 올리면 운반자가 내용을 보고 접수하는 방식으로 준비하고 있어요. 현재는 이 아이폰에 임시 보관만 할 수 있어요.").font(.subheadline)
            if draft.pickup.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("요청을 올리기 전 물건 있는 곳의 픽업 주소를 확인해야 해요.").font(.caption).foregroundStyle(.secondary)
            }
            Text("배송비는 거리·운반 조건을 확인한 뒤 안내할 예정이에요.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func applyPreview() {
        guard let preview = importer.preview else { return }
        let filled = autofill.apply(preview, to: &draft)
        autofillNotice = filled ? "물품명을 자동으로 채웠어요. 아래에서 수정할 수 있어요." : "직접 입력한 물품명은 유지했어요. 불러온 제목과 비교해주세요."
    }
    private func changeLink(_ value: String) {
        guard value != draft.link else { return }
        importer.reset()
        autofill.clearImportedValues(from: &draft)
        autofillNotice = nil
        draft.link = value
    }
    private func keepDraft() {
        do { try store.save(draft); onSaved(); if editing { dismiss() } }
        catch { message = AppMessage(title: "임시 보관하지 못했어요", text: error.localizedDescription) }
    }
    private func dismissKeyboard() {
        focusedInput = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func advance() {
        dismissKeyboard()
        do {
            if step == 0 {
                guard !draft.item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppInputError("물품 이름을 입력해주세요.") }
                if !draft.link.isEmpty { _ = try ListingLink.parse(draft.link) }
                step = 1
            } else if step == 1 { try draft.validate(requirePickup: false); step = 2 }
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
        Section(stop == .pickup ? "물건 있는 곳 · 픽업지" : "받는 곳 · 도착지") {
            if stop == .pickup {
                Text("물건을 가져올 주소를 입력해주세요. 다른 사람의 물건이라면 건네줄 분에게 확인하고, 아직 모르면 나중에 입력할 수 있어요.").font(.caption).foregroundStyle(.secondary)
            }
            Button { search = true } label: { Label(address.line.isEmpty ? "주소 찾기" : "주소 다시 찾기", systemImage: "magnifyingglass") }
            TextField("기본 주소", text: Binding(get: { address.line }, set: { address.editLine($0) }), axis: .vertical).lineLimit(1...3)
            TextField("상세주소 · 동·호수 등", text: $address.detail)
            if stop == .dropoff { HStack {
                Button("저장 주소 선택") { saved = true }.disabled(store.data.addresses.isEmpty)
                Spacer()
                Button("받는 주소 저장") {
                    do { try store.saveAddress(address, label: "받을 곳"); message = AppMessage(title: "주소 저장", text: "이 아이폰에 받을 주소를 저장했어요.") }
                    catch { message = AppMessage(title: "저장하지 못했어요", text: error.localizedDescription) }
                }.disabled(address.line.isEmpty)
            }.font(.caption) }
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
