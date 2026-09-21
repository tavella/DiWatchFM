import XCTest
import Security
@testable import DiWatchApp

final class KeychainManagerSecurityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainManager.shared.clearAll()
    }

    override func tearDown() {
        KeychainManager.shared.clearAll()
        super.tearDown()
    }

    func testSaveAndLoadListenKey() {
        let testKey = "test_listen_key_12345"
        KeychainManager.shared.saveListenKey(testKey)
        
        XCTAssertEqual(KeychainManager.shared.currentListenKey, testKey)
        
        // Verify via direct Security framework query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.di.watchfm",
            kSecAttrAccount as String: "com.di.watchfm.listenkey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        XCTAssertEqual(status, errSecSuccess, "Item should be retrievable from Keychain")
        
        if let data = dataTypeRef as? Data, let loaded = String(data: data, encoding: .utf8) {
            XCTAssertEqual(loaded, testKey)
        } else {
            XCTFail("Failed to decode data from Keychain")
        }
    }

    func testSaveAndLoadCredentials() {
        let username = "enterprise_test_user@example.com"
        let password = "SuperSecretPassword123!"
        
        KeychainManager.shared.saveCredentials(username: username, password: password)
        
        XCTAssertEqual(KeychainManager.shared.currentUsername, username)
        XCTAssertEqual(KeychainManager.shared.currentPassword, password)
    }

    func testClearAllRemovesStoredItems() {
        KeychainManager.shared.saveListenKey("temporary_key")
        KeychainManager.shared.saveCredentials(username: "temp_user", password: "temp_password")
        
        KeychainManager.shared.clearAll()
        
        XCTAssertTrue(KeychainManager.shared.currentListenKey.isEmpty)
        XCTAssertTrue(KeychainManager.shared.currentUsername.isEmpty)
        XCTAssertTrue(KeychainManager.shared.currentPassword.isEmpty)
        XCTAssertTrue(KeychainManager.shared.currentSessionKey.isEmpty)
    }
}
