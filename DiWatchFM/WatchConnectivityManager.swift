import Foundation
import WatchConnectivity
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.di.watchfm", category: "WatchConnectivity")

@Observable
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    #endif
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.processReceivedCredentials(applicationContext)
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        DispatchQueue.main.async {
            self.processReceivedCredentials(userInfo)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.processReceivedCredentials(message)
        }
    }
    
    private func processReceivedCredentials(_ payload: [String: Any]) {
        if let isLogout = payload["isLogout"] as? Bool, isLogout {
            KeychainManager.shared.clearAll()
            logger.info("Cleared credentials on Apple Watch following companion logout.")
            return
        }
        
        if let listenKey = payload["listenKey"] as? String, !listenKey.isEmpty {
            KeychainManager.shared.saveListenKey(listenKey)
        }
        
        if let sessionKey = payload["sessionKey"] as? String, !sessionKey.isEmpty {
            KeychainManager.shared.saveSessionKey(sessionKey)
        }
        
        if let username = payload["username"] as? String,
           let password = payload["password"] as? String {
            if !username.isEmpty && !password.isEmpty {
                KeychainManager.shared.saveCredentials(username: username, password: password)
            }
        }
        logger.info("Successfully synced credentials from companion app.")
    }
}
