import SwiftUI

@main
struct DiWatchFMApp: App {
    init() {
        // Force initialization of KeychainManager so default key seeds if needed
        _ = KeychainManager.shared
        _ = WatchConnectivityManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            StationListView()
                .environment(WatchAudioPlayer.shared)
        }
    }
}
