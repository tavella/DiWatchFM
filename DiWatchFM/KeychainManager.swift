import Foundation
import Security

@Observable
final class KeychainManager {
    static let shared = KeychainManager()
    
    private let listenKeyAccount = "com.di.watchfm.listenkey"
    private let sessionKeyAccount = "com.di.watchfm.sessionkey"
    private let usernameAccount = "com.di.watchfm.username"
    private let passwordAccount = "com.di.watchfm.password"
    private let service = "com.di.watchfm"
    
    var currentListenKey: String = ""
    var currentSessionKey: String = ""
    var currentUsername: String = ""
    var currentPassword: String = ""
    
    init() {
        self.currentListenKey = loadItem(account: listenKeyAccount) ?? ""
        self.currentSessionKey = loadItem(account: sessionKeyAccount) ?? ""
        self.currentUsername = loadItem(account: usernameAccount) ?? ""
        self.currentPassword = loadItem(account: passwordAccount) ?? ""
    }
    
    func saveListenKey(_ key: String) {
        saveItem(account: listenKeyAccount, value: key)
        self.currentListenKey = key
    }
    
    func saveSessionKey(_ key: String) {
        saveItem(account: sessionKeyAccount, value: key)
        self.currentSessionKey = key
    }
    
    func saveCredentials(username: String, password: String) {
        saveItem(account: usernameAccount, value: username)
        saveItem(account: passwordAccount, value: password)
        self.currentUsername = username
        self.currentPassword = password
    }
    
    private func saveItem(account: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
    
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        currentListenKey = ""
        currentSessionKey = ""
        currentUsername = ""
        currentPassword = ""
    }
    
    private func loadItem(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
