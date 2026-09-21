import XCTest
import WatchConnectivity
@testable import DiWatchApp

final class WatchConnectivityManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainManager.shared.clearAll()
    }

    override func tearDown() {
        KeychainManager.shared.clearAll()
        super.tearDown()
    }

    func testReceiveMessageSyncsCredentials() {
        let manager = WatchConnectivityManager.shared
        let dummySession = WCSession.default

        let expectation = expectation(description: "Process message credentials")
        let payload: [String: Any] = [
            "listenKey": "wc_synced_listen_key",
            "username": "wc_user@example.com",
            "password": "wc_password_123"
        ]

        manager.session(dummySession, didReceiveMessage: payload)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(KeychainManager.shared.currentListenKey, "wc_synced_listen_key")
            XCTAssertEqual(KeychainManager.shared.currentUsername, "wc_user@example.com")
            XCTAssertEqual(KeychainManager.shared.currentPassword, "wc_password_123")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testReceiveApplicationContextSyncsCredentials() {
        let manager = WatchConnectivityManager.shared
        let dummySession = WCSession.default

        let expectation = expectation(description: "Process application context credentials")
        let payload: [String: Any] = [
            "listenKey": "context_key",
            "username": "context_user",
            "password": "context_password"
        ]

        manager.session(dummySession, didReceiveApplicationContext: payload)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(KeychainManager.shared.currentListenKey, "context_key")
            XCTAssertEqual(KeychainManager.shared.currentUsername, "context_user")
            XCTAssertEqual(KeychainManager.shared.currentPassword, "context_password")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testActivationCallbacksDoNotCrash() {
        let manager = WatchConnectivityManager.shared
        let dummySession = WCSession.default

        manager.session(dummySession, activationDidCompleteWith: .activated, error: nil)
        manager.session(dummySession, activationDidCompleteWith: .notActivated, error: NSError(domain: "test", code: -1))
    }
}
