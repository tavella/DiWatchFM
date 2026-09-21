import Foundation
import WatchConnectivity
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.di.watchfm", category: "WatchSync")

private struct MemberSessionResponse: Codable {
    let key: String?
    let member: MemberData?
    
    struct MemberData: Codable {
        let listenKey: String?
        let userType: String?
        let email: String?
        
        enum CodingKeys: String, CodingKey {
            case listenKey = "listen_key"
            case userType = "user_type"
            case email
        }
    }
}

@Observable
class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()
    
    var isReachable: Bool = false
    var isPaired: Bool = false
    var isWatchAppInstalled: Bool = false
    var isAuthenticating: Bool = false
    var lastSyncError: String? = nil
    var lastSyncDate: Date? = nil
    
    var userEmail: String {
        get { UserDefaults.standard.string(forKey: "com.di.watchfm.userEmail") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "com.di.watchfm.userEmail") }
    }
    
    var userType: String {
        get { UserDefaults.standard.string(forKey: "com.di.watchfm.userType") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "com.di.watchfm.userType") }
    }
    
    var currentListenKey: String {
        KeychainManager.shared.currentListenKey
    }
    
    var currentUsername: String {
        KeychainManager.shared.currentUsername
    }
    
    var isLoggedIn: Bool {
        !KeychainManager.shared.currentListenKey.isEmpty || !userEmail.isEmpty
    }
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            if let error = error {
                logger.error("WCSession activation failed: \(error.localizedDescription)")
            } else {
                logger.info("WCSession activated with state: \(activationState.rawValue), isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled), isReachable: \(session.isReachable)")
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            logger.info("WCSession watch state changed: isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    // MARK: - Automated Authentication & Key Retrieval
    
    /// Authenticates with DI.FM via credentials, retrieves the Listen Key and Session Key,
    /// persists them to hardware Keychain, and syncs them to Apple Watch.
    @MainActor
    func authenticateAndSync(username: String, password: String) async -> Bool {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            self.lastSyncError = "Please enter both username and password."
            return false
        }
        
        self.isAuthenticating = true
        self.lastSyncError = nil
        
        defer {
            self.isAuthenticating = false
        }
        
        guard let url = URL(string: "https://api.audioaddict.com/v1/di/member_sessions") else {
            self.lastSyncError = "Invalid server URL configuration."
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Basic Auth: streams:diradio
        let authString = "streams:diradio"
        if let authData = authString.data(using: .utf8) {
            request.setValue("Basic \(authData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        
        let payload: [String: Any] = [
            "member_session": [
                "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
                "password": password
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            self.lastSyncError = "Failed to serialize credentials: \(error.localizedDescription)"
            return false
        }
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 15.0
        let session = URLSession(configuration: sessionConfig)
        
        logger.info("Sending authentication request for user")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                self.lastSyncError = "Unexpected response from DI.FM server."
                return false
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    self.lastSyncError = "Invalid username or password. Please check your credentials."
                } else {
                    self.lastSyncError = "DI.FM server error (HTTP \(httpResponse.statusCode)). Please try again later."
                }
                return false
            }
            
            let decoded = try JSONDecoder().decode(MemberSessionResponse.self, from: data)
            guard let listenKey = decoded.member?.listenKey, !listenKey.isEmpty else {
                self.lastSyncError = "Login succeeded, but no Listen Key was returned for this account."
                return false
            }
            
            let sessionKey = decoded.key ?? ""
            let email = decoded.member?.email ?? username
            let type = decoded.member?.userType ?? "listener"
            
            // Store locally in Keychain and UserDefaults
            KeychainManager.shared.saveListenKey(listenKey)
            if !sessionKey.isEmpty {
                KeychainManager.shared.saveSessionKey(sessionKey)
            }
            KeychainManager.shared.saveCredentials(username: username, password: password)
            self.userEmail = email
            self.userType = type
            
            logger.info("Successfully retrieved listen key from DI.FM. Syncing to Watch...")
            
            // Sync credentials to Apple Watch
            self.syncCredentials(
                listenKey: listenKey,
                sessionKey: sessionKey,
                username: username,
                password: password
            )
            return true
            
        } catch {
            self.lastSyncError = "Connection error: \(error.localizedDescription)"
            logger.error("Authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Watch Connectivity Sync
    
    func syncCredentials(
        listenKey: String,
        sessionKey: String = "",
        username: String = "",
        password: String = ""
    ) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            DispatchQueue.main.async {
                self.lastSyncError = "Apple Watch session not ready. Please ensure Bluetooth is enabled."
            }
            return
        }
        
        guard session.isPaired else {
            DispatchQueue.main.async {
                self.lastSyncError = "No Apple Watch is paired to this iPhone."
            }
            return
        }
        
        guard session.isWatchAppInstalled else {
            DispatchQueue.main.async {
                self.lastSyncError = "Watch app is not recognized as installed. Open the iPhone 'Watch' app and tap 'Install' or toggle 'Show App on Apple Watch' for DiWatchFM."
            }
            return
        }
        
        var payload: [String: Any] = [
            "listenKey": listenKey
        ]
        if !sessionKey.isEmpty {
            payload["sessionKey"] = sessionKey
        }
        if !username.isEmpty {
            payload["username"] = username
        }
        if !password.isEmpty {
            payload["password"] = password
        }
        
        var succeeded = false
        
        do {
            try session.updateApplicationContext(payload)
            succeeded = true
            logger.info("Updated application context with credentials")
        } catch {
            logger.error("Failed to update application context: \(error.localizedDescription)")
        }
        
        session.transferUserInfo(payload)
        succeeded = true
        
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                logger.error("Failed to send message: \(error.localizedDescription)")
            }
        }
        
        DispatchQueue.main.async {
            if succeeded {
                self.lastSyncDate = Date()
                self.lastSyncError = nil
            } else {
                self.lastSyncError = "Failed to sync credentials to Apple Watch."
            }
        }
    }
    
    func reSync() {
        let listenKey = KeychainManager.shared.currentListenKey
        let sessionKey = KeychainManager.shared.currentSessionKey
        let username = KeychainManager.shared.currentUsername
        let password = KeychainManager.shared.currentPassword
        guard !listenKey.isEmpty else {
            self.lastSyncError = "No credentials to sync. Please log in first."
            return
        }
        syncCredentials(listenKey: listenKey, sessionKey: sessionKey, username: username, password: password)
    }
    
    func logout() {
        KeychainManager.shared.clearAll()
        userEmail = ""
        userType = ""
        lastSyncDate = nil
        lastSyncError = nil
        
        // Notify Apple Watch to purge credentials as well
        if WCSession.default.activationState == .activated {
            let payload: [String: Any] = ["isLogout": true]
            try? WCSession.default.updateApplicationContext(payload)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
            }
        }
    }
}
