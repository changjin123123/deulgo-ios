import Foundation
import UIKit
import Combine
import KakaoSDKCommon
import KakaoSDKNavi

@MainActor protocol NavigationURLOpening {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL) async -> Bool
}

@MainActor struct SystemURLOpener: NavigationURLOpening {
    func canOpen(_ url: URL) -> Bool { UIApplication.shared.canOpenURL(url) }
    func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
    }
}

struct NavigationLaunchRequest {
    let provider: NavigationProvider
    let url: URL
    let installURL: URL
}

@MainActor enum NavigationRequestFactory {
    static func make(provider: NavigationProvider, destination: NavigationDestination) throws -> NavigationLaunchRequest {
        switch provider {
        case .naver:
            let url = try NaverNavigationURL.make(destination: destination,
                                                 bundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            return NavigationLaunchRequest(provider: provider, url: url,
                                           installURL: URL(string: "https://apps.apple.com/app/id311867728")!)
        case .kakao:
            // The SDK accesses its key with try!: never call it before valid initialization.
            guard AppConfiguration.kakaoKey != nil,
                  (try? KakaoSDK.shared.appKey()) != nil else { throw DestinationError.missingKakaoKey }
            let location = NaviLocation(name: destination.name,
                                        x: String(destination.longitude), y: String(destination.latitude))
            guard let url = NaviApi.shared.navigateUrl(destination: location,
                                                       option: NaviOption(coordType: .WGS84)) else {
                throw DestinationError.invalidURL
            }
            return NavigationLaunchRequest(provider: provider, url: url,
                                           installURL: NaviApi.webNaviInstallUrl)
        }
    }
}

struct NavigationNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var installURL: URL?
}

@MainActor final class ExternalNavigation: ObservableObject {
    @Published var notice: NavigationNotice?
    @Published private(set) var isOpening = false
    private let opener: any NavigationURLOpening

    init(opener: any NavigationURLOpening) { self.opener = opener }

    func launch(_ request: NavigationLaunchRequest) async {
        guard !isOpening else { return }
        notice = nil
        guard opener.canOpen(request.url) else {
            notice = NavigationNotice(title: "\(request.provider.title) 설치 확인",
                                      message: "앱을 열 수 없어요. 설치 상태를 확인한 뒤 다시 시도해주세요.",
                                      installURL: request.installURL)
            return
        }
        isOpening = true
        defer { isOpening = false }
        let opened = await opener.open(request.url)
        if !opened {
            notice = NavigationNotice(title: "연결하지 못했어요", message: "잠시 후 다시 시도하거나 다른 지도 앱을 선택해주세요.")
        }
        // opened means iOS accepted the launch, not route acceptance or delivery completion.
    }

    func openInstallPage(_ url: URL) async {
        if !(await opener.open(url)) {
            notice = NavigationNotice(title: "설치 안내를 열지 못했어요", message: "App Store에서 해당 지도 앱을 검색해주세요.")
        }
    }
}
