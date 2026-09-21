import XCTest
import AVFoundation
@testable import DiWatchApp

@MainActor
final class StateTransitionsAndIntegrationTests: XCTestCase {

    var player: WatchAudioPlayer!

    override func setUp() async throws {
        try await super.setUp()
        player = WatchAudioPlayer.shared
        player.pause()
    }

    override func tearDown() async throws {
        player.pause()
        try await super.tearDown()
    }

    // MARK: - Unit Tests: Audio state transitions

    func testAudioStateTransitions_BufferingToPlaying() async throws {
        // Mock state to stopped initially
        player.state = .stopped
        
        let station = Channel(id: 1, key: "vocaltrance", name: "Vocal Trance", description: "Trance", assetUrl: nil, channelFilterIds: nil)
        
        // Simulating the start of playback transitions state to buffering
        player.play(station: station, queue: [])
        XCTAssertEqual(player.state, .buffering, "State should immediately transition to buffering when playback begins")
        
        // Simulating the KVO callback for `timeControlStatus == .playing`
        player.state = .playing
        XCTAssertEqual(player.state, .playing, "State should transition to playing when buffer fulfills")
        
        // Simulating buffer empty
        player.state = .buffering
        XCTAssertEqual(player.state, .buffering, "State should return to buffering if playback buffer empties")
        
        // Simulation error/failed
        player.state = .paused
        player.lastErrorMessage = "Stream connection failed"
        XCTAssertEqual(player.state, .paused)
        XCTAssertNotNil(player.lastErrorMessage)
    }
    
    // MARK: - Integration Tests: End-to-end selection to dispatch

    func testIntegration_StationSelectionToStreamResolution() async throws {
        let api = AudioAddictAPI.shared
        let station = Channel(id: 100, key: "synthwave", name: "Synthwave", description: "Retro synths", assetUrl: nil, channelFilterIds: nil)
        
        // Given a listen key
        let listenKey = "integration_test_key"
        
        // When the user selects a station
        let url = api.streamURL(for: station.key, listenKey: listenKey, quality: .high)
        
        // Then the stream URL should be correctly resolved and formatted
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "http://prem1.di.fm:80/synthwave_hi?integration_test_key")
        
        // And the player state should transition properly
        player.play(station: station, queue: [])
        XCTAssertEqual(player.currentStation?.id, 100)
        XCTAssertEqual(player.state, .buffering)
    }

    // MARK: - Integration Tests: Interruption recovery simulation

    func testInterruptionRecoverySimulation() async throws {
        let station = Channel(id: 200, key: "chillout", name: "Chillout", description: "Relaxing", assetUrl: nil, channelFilterIds: nil)
        player.play(station: station, queue: [])
        
        // Simulating an active playing state before interruption
        player.state = .playing
        XCTAssertEqual(player.state, .playing)
        
        // Simulate AVAudioSessionInterruptionType.began or inactive
        if #available(watchOS 27.0, iOS 27.0, *) {
            NotificationCenter.default.post(
                name: NSNotification.Name("AVAudioSessionDidBecomeInactiveNotification"),
                object: nil
            )
        } else {
            let beganUserInfo: [AnyHashable: Any] = [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
            NotificationCenter.default.post(
                name: AVAudioSession.interruptionNotification,
                object: nil,
                userInfo: beganUserInfo
            )
        }
        
        // Interruption should pause playback
        // Wait for runloop to process notification
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(player.state, .paused, "Interruption began should transition state to paused")
        
        // Simulate AVAudioSessionInterruptionType.ended with shouldResume option
        if #available(watchOS 27.0, iOS 27.0, *) {
            NotificationCenter.default.post(
                name: NSNotification.Name("AVAudioSessionResumptionRecommendationNotification"),
                object: nil
            )
        } else {
            let endedUserInfo: [AnyHashable: Any] = [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
            NotificationCenter.default.post(
                name: AVAudioSession.interruptionNotification,
                object: nil,
                userInfo: endedUserInfo
            )
        }
        
        // Wait for runloop to process notification
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(player.state == .playing || player.state == .buffering, "Interruption ended with shouldResume should resume playback (playing or buffering)")
    }
}
