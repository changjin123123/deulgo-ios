import SwiftUI
import KakaoSDKCommon

@main struct DeulgoApp: App {
    init() {
        if let key = AppConfiguration.kakaoKey {
            KakaoSDK.initSDK(appKey: key, loggingEnable: false)
        }
    }
    var body: some Scene {
        WindowGroup {
            DeulgoRootView()
                .tint(Color(red: 0.16, green: 0.40, blue: 0.32))
        }
    }
}
