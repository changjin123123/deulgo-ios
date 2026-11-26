import SwiftUI

struct DeliveryNavigationView: View {
    @StateObject private var store: DraftStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigation = ExternalNavigation(opener: SystemURLOpener())
    @State private var editingStop: DeliveryStop?
    @State private var confirmingClear = false

    init(pickup: NavigationDestination? = nil, dropoff: NavigationDestination? = nil) {
        // Per-request state: never inherit another request's destination or write during View.init.
        let draft = NavigationDraft(pickup: pickup, dropoff: dropoff,
                                    selectedStop: pickup == nil && dropoff != nil ? .dropoff : .pickup)
        _store = StateObject(wrappedValue: DraftStore(draft: draft))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("어디로 이동할까요?").font(.title2.bold())
                        Text("위치를 확인하고, 익숙한 내비로 출발하세요.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Section("이동할 장소") {
                    ForEach(DeliveryStop.allCases) { stop in
                        Button { editingStop = stop } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: stop.icon).frame(width: 24).padding(.top, 3)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(stop.title).font(.caption).foregroundStyle(.secondary)
                                    if let destination = store.draft.destination(for: stop) {
                                        Text(destination.name).font(.headline).foregroundStyle(.primary)
                                        Text(destination.address).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    } else { Text("위치 선택").font(.headline) }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 8)
                        }
                    }
                }
                Section("길 안내") {
                    Picker("이동할 곳", selection: Binding(get: { store.draft.selectedStop }, set: { store.select($0) })) {
                        ForEach(DeliveryStop.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    if let destination = store.draft.selectedDestination {
                        Label("현재 위치 → \(destination.name)", systemImage: "location")
                            .font(.subheadline).padding(.vertical, 4)
                    } else {
                        Text("먼저 \(store.draft.selectedStop.title)를 선택해주세요.").foregroundStyle(.secondary)
                    }
                    ForEach(NavigationProvider.allCases) { provider in
                        Button { launch(provider) } label: {
                            HStack {
                                Text("\(provider.title)로 길 안내")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                            }.padding(.vertical, 8)
                        }
                        .disabled(store.draft.selectedDestination == nil || navigation.isOpening)
                    }
                } footer: {
                    Text("선택한 앱에 장소 이름과 위치를 전달해요. 현재 위치와 경로는 내비 앱에서 확인해주세요. 차량 종류와 통행 제한도 내비 앱에서 확인할 수 있어요.")
                }
                if let message = store.storageMessage {
                    Section { Text(message).foregroundStyle(.orange) }
                }
                Section {
                    Button("이 화면의 위치 지우기", role: .destructive) { confirmingClear = true }
                } footer: { Text("이 화면에서 위치를 바꿔도 저장된 배송 요청은 바뀌지 않아요.") }
            }
            .navigationTitle("들고 · 길 안내")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .sheet(item: $editingStop) { stop in PlaceSearchView(stop: stop) { store.set($0, for: stop) } }
            .confirmationDialog("저장된 픽업지와 도착지를 지울까요?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("위치 지우기", role: .destructive) { store.clear() }
                Button("취소", role: .cancel) {}
            }
            .alert(item: $navigation.notice) { notice in
                if let installURL = notice.installURL {
                    return Alert(title: Text(notice.title), message: Text(notice.message),
                                 primaryButton: .default(Text("설치 안내")) { Task { await navigation.openInstallPage(installURL) } },
                                 secondaryButton: .cancel(Text("취소")))
                }
                return Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("확인")))
            }
        }
    }

    private func launch(_ provider: NavigationProvider) {
        guard let destination = store.draft.selectedDestination else { return }
        do {
            let request = try NavigationRequestFactory.make(provider: provider, destination: destination)
            Task { await navigation.launch(request) }
        } catch {
            navigation.notice = NavigationNotice(title: "길 안내 확인", message: error.localizedDescription)
        }
    }
}
