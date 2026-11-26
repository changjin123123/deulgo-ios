import SwiftUI

enum DeulgoTab: Hashable { case home, send, carry, history }

struct DeulgoRootView: View {
    @StateObject private var store = DeulgoStore()
    @State private var tab: DeulgoTab = .home
    var body: some View {
        TabView(selection: $tab) {
            HomeView(tab: $tab).tabItem { Label("홈", systemImage: "house") }.tag(DeulgoTab.home)
            NewShipmentView { tab = .history }.tabItem { Label("보내기", systemImage: "shippingbox") }.tag(DeulgoTab.send)
            CarrierHomeView().tabItem { Label("운반하기", systemImage: "car") }.tag(DeulgoTab.carry)
            RequestHistoryView().tabItem { Label("내역", systemImage: "clock") }.tag(DeulgoTab.history)
        }
        .environmentObject(store)
        .tint(DeulgoStyle.green)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: DeulgoStore
    @Binding var tab: DeulgoTab
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "shippingbox.fill").font(.system(size: 40)).foregroundStyle(DeulgoStyle.green)
                        Text("보내고 싶은 물건,\n가는 김에 들고.").font(.largeTitle.bold()).foregroundStyle(Color(red: 0.10, green: 0.23, blue: 0.18))
                        Text("중고거래 물품도, 일상에서 보낼 물건도.")
                            .font(.subheadline).foregroundStyle(Color(red: 0.27, green: 0.36, blue: 0.29))
                        PrimaryAction(title: "물건 보내기", icon: "shippingbox") { tab = .send }
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(DeulgoStyle.cream, in: RoundedRectangle(cornerRadius: 26))
                    Button { tab = .carry } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "car.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("가는 김에 운반하기").font(.headline)
                                Text("운반 요청을 둘러보고 내 차량을 준비해요").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right")
                        }.padding(20).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                    HStack {
                        Text("임시 보관한 요청").font(.headline)
                        Spacer()
                        Button("모두 보기") { tab = .history }
                    }
                    if let request = store.data.requests.first {
                        Button { tab = .history } label: { RequestCard(request: request) }.buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("임시 보관한 요청이 없어요").font(.headline)
                            Text("물품과 주소를 입력하면 여기서 다시 확인할 수 있어요.").font(.subheadline).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let error = store.storageError { Text(error).font(.caption).foregroundStyle(.red) }
                    LocalModeNote()
                }.padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("들고")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { AppInfoView() } label: { Image(systemName: "person.crop.circle") } } }
        }
    }
}

struct RequestCard: View {
    let request: ShipmentDraft
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(request.item).font(.headline).lineLimit(2)
                Spacer()
                Text("임시 보관").font(.caption.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(DeulgoStyle.green.opacity(0.10), in: Capsule())
            }
            Label(request.pickup.line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "픽업 주소 확인 필요" : request.pickup.line, systemImage: "circle").lineLimit(1)
            Label(request.dropoff.line, systemImage: "mappin").lineLimit(1)
            Text(request.arrival.title).font(.caption).foregroundStyle(.secondary)
        }.font(.subheadline).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct AppInfoView: View {
    @EnvironmentObject private var store: DeulgoStore
    @State private var message: AppMessage?
    var body: some View {
        List {
            Section("내 아이폰에 저장됨") {
                LabeledContent("배송 요청", value: "\(store.data.requests.count)개")
                LabeledContent("운반수단", value: "\(store.data.vehicles.count)대")
                NavigationLink("저장한 주소") { AddressBookView() }
            }
            Section("현재 이용 범위") {
                Text("앱 사용 흐름을 확인하는 버전이에요. 실제 배차·결제·운반 요청 공개는 아직 이용할 수 없어요.")
                Text("저장한 내용은 다른 기기나 기존 웹과 동기화되지 않아요.")
            }.font(.subheadline)
            Section("개인정보") {
                Text("주소 검색 때 검색어를 Apple 지도에 보내고, 길 안내 때 선택한 장소 이름과 좌표를 내비 앱에 전달해요. 상품 링크를 입력하면 해당 거래글의 공개 정보를 자동 조회해요.")
            }.font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("내 정보")
    }
}
