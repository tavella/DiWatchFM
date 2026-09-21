import XCTest
@testable import DiWatchApp

final class WatchAudioPlayerVotingTests: XCTestCase {

    private var player: WatchAudioPlayer!
    private let trackVotesKey = "com.di.watchfm.trackVotes"
    private var originalVotes: [String: String]?

    override func setUp() {
        super.setUp()
        player = WatchAudioPlayer.shared
        originalVotes = UserDefaults.standard.dictionary(forKey: trackVotesKey) as? [String: String]
        UserDefaults.standard.removeObject(forKey: trackVotesKey)
        player.pause()
    }

    override func tearDown() {
        player.pause()
        if let original = originalVotes {
            UserDefaults.standard.set(original, forKey: trackVotesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: trackVotesKey)
        }
        super.tearDown()
    }

    func testVoteWithoutStationDoesNothing() {
        player.currentStation = nil
        player.currentTrackId = 555
        player.toggleVoteUp()

        XCTAssertEqual(player.currentTrackVote, .none)
        XCTAssertEqual(player.voteFor(trackId: 555), .none)
    }

    func testToggleVoteUpAndDown() {
        let station = Channel(id: 1, key: "trance", name: "Trance", description: "", assetUrl: nil, channelFilterIds: nil)
        player.currentStation = station
        player.currentTrackId = 12345

        // Initial state
        XCTAssertEqual(player.currentTrackVote, .none)
        XCTAssertEqual(player.voteFor(trackId: 12345), .none)

        // Vote Up
        player.toggleVoteUp()
        XCTAssertEqual(player.currentTrackVote, .up)
        XCTAssertEqual(player.voteFor(trackId: 12345), .up)

        // Verify UserDefaults saved
        let savedVotesAfterUp = UserDefaults.standard.dictionary(forKey: trackVotesKey) as? [String: String]
        XCTAssertEqual(savedVotesAfterUp?["12345"], "up")

        // Toggling Up again removes the vote (toggle off)
        player.toggleVoteUp()
        XCTAssertEqual(player.currentTrackVote, .none)
        XCTAssertEqual(player.voteFor(trackId: 12345), .none)

        let savedVotesAfterRemoval = UserDefaults.standard.dictionary(forKey: trackVotesKey) as? [String: String]
        XCTAssertNil(savedVotesAfterRemoval?["12345"])

        // Vote Down
        player.toggleVoteDown()
        XCTAssertEqual(player.currentTrackVote, .down)
        XCTAssertEqual(player.voteFor(trackId: 12345), .down)

        let savedVotesAfterDown = UserDefaults.standard.dictionary(forKey: trackVotesKey) as? [String: String]
        XCTAssertEqual(savedVotesAfterDown?["12345"], "down")

        // Switch directly from Down to Up
        player.toggleVoteUp()
        XCTAssertEqual(player.currentTrackVote, .up)
        XCTAssertEqual(player.voteFor(trackId: 12345), .up)

        // Clean up
        player.toggleVoteUp()
        XCTAssertEqual(player.currentTrackVote, .none)
    }

    func testVoteForDifferentTrackIdDoesNotAffectCurrentTrackVote() {
        let station = Channel(id: 1, key: "trance", name: "Trance", description: "", assetUrl: nil, channelFilterIds: nil)
        player.currentStation = station
        player.currentTrackId = 100

        // Vote for another track in history
        player.vote(trackId: 200, direction: .up)

        XCTAssertEqual(player.currentTrackVote, .none, "currentTrackVote should remain none for track 100")
        XCTAssertEqual(player.voteFor(trackId: 200), .up)
        XCTAssertEqual(player.voteFor(trackId: 100), .none)

        // Clean up
        player.vote(trackId: 200, direction: .up)
    }
}
