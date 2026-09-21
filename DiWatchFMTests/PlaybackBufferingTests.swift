import XCTest
import AVFoundation
@testable import DiWatchApp

final class PlaybackBufferingTests: XCTestCase {

    var player: WatchAudioPlayer!

    override func setUp() {
        super.setUp()
        player = WatchAudioPlayer.shared
        player.pause()
    }

    override func tearDown() {
        player.pause()
        super.tearDown()
    }

    func testInitialPlaybackState() {
        XCTAssertTrue(player.state == .stopped || player.state == .paused, "Initial state should be idle")
        XCTAssertNil(player.lastErrorMessage, "Error message should initially be nil")
    }

    func testQualitySwitching() {
        let initialQuality = player.currentQuality
        let targetQuality: AudioQuality = initialQuality == .high ? .standard : .high
        
        player.setAudioQuality(targetQuality)
        XCTAssertEqual(player.currentQuality, targetQuality, "Audio quality should update to target quality")
        
        // Restore initial
        player.setAudioQuality(initialQuality)
        XCTAssertEqual(player.currentQuality, initialQuality)
    }

    func testPauseResetsState() {
        player.pause()
        XCTAssertEqual(player.state, .paused, "Pausing should transition state to paused")
        XCTAssertNil(player.lastErrorMessage)
    }

    func testSkipQueueWrapping() {
        let channel1 = Channel(id: 1, key: "trance", name: "Trance", description: "Vocal and uplifting trance", assetUrl: nil, channelFilterIds: nil)
        let channel2 = Channel(id: 2, key: "house", name: "House", description: "Deep and soulful house", assetUrl: nil, channelFilterIds: nil)
        let queue = [channel1, channel2]
        
        player.play(station: channel1, queue: queue)
        XCTAssertEqual(player.currentStation?.id, 1)
        
        player.skipForward()
        XCTAssertEqual(player.currentStation?.id, 2)
        
        // Wrapping forward
        player.skipForward()
        XCTAssertEqual(player.currentStation?.id, 1)
        
        // Wrapping backward
        player.skipBackward()
        XCTAssertEqual(player.currentStation?.id, 2)
        
        player.pause()
    }
}
