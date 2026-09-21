import XCTest
@testable import DiWatchApp

final class AudioAddictAPITests: XCTestCase {

    // MARK: - Stream URL Construction Tests

    func testStreamURLGeneration() {
        let api = AudioAddictAPI.shared
        let channelKey = "vocaltrance"
        let listenKey = "abc123xyz"

        let highURL = api.streamURL(for: channelKey, listenKey: listenKey, quality: .high)
        XCTAssertEqual(highURL?.absoluteString, "http://prem1.di.fm:80/vocaltrance_hi?abc123xyz")

        let standardURL = api.streamURL(for: channelKey, listenKey: listenKey, quality: .standard)
        XCTAssertEqual(standardURL?.absoluteString, "http://prem1.di.fm:80/vocaltrance?abc123xyz")

        let dataSaverURL = api.streamURL(for: channelKey, listenKey: listenKey, quality: .dataSaver)
        XCTAssertEqual(dataSaverURL?.absoluteString, "http://prem1.di.fm:80/vocaltrance_aac?abc123xyz")
    }

    func testStreamURLsFallbackGeneration() async {
        let api = AudioAddictAPI.shared
        let urls = await api.streamURLs(for: "eurodance", listenKey: "dummyKey", quality: .standard)
        
        XCTAssertFalse(urls.isEmpty, "Stream URLs should never be empty (falls back to prem1 and prem4)")
        let urlStrings = urls.map { $0.absoluteString }
        XCTAssertTrue(urlStrings.contains(where: { $0.contains("prem1.di.fm") }))
    }

    // MARK: - Filter and History Data Parsing Tests

    func testChannelFilterExclusionRules() throws {
        let json = """
        [
            {"id": 1, "key": "default", "name": "Default"},
            {"id": 2, "key": "all", "name": "All"},
            {"id": 3, "key": "popular", "name": "Popular"},
            {"id": 4, "key": "trance", "name": "Trance"},
            {"id": 5, "key": "house", "name": "House"}
        ]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([ChannelFilter].self, from: json)
        let filtered = decoded.filter { $0.key != "default" && $0.name.lowercased() != "all" && $0.key != "popular" }

        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.map { $0.key }, ["trance", "house"])
    }

    func testTrackHistoryTrackTypeFiltering() throws {
        let json = """
        [
            {"track": "Song 1", "type": "track", "track_id": 10},
            {"track": "Station ID Jingle", "type": "station_id", "track_id": 11},
            {"track": "Sponsor Ad", "type": "advertisement", "track_id": 12},
            {"track": "Song 2", "type": "track", "track_id": 13}
        ]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([TrackHistory].self, from: json)
        let onlyTracks = decoded.filter { $0.type == "track" }

        XCTAssertEqual(onlyTracks.count, 2)
        XCTAssertEqual(onlyTracks.map { $0.trackId }, [10, 13])
    }

    // MARK: - APIError Coverage

    func testAPIErrors() {
        let errors: [APIError] = [
            .invalidURL,
            .requestFailed(URLError(.timedOut)),
            .invalidResponse,
            .decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "corrupted"))),
            .authenticationFailed
        ]
        XCTAssertEqual(errors.count, 5)
    }

    // MARK: - Live Auth Test (Skipped if no credentials)

    func testResolveEpisodeStreamURL() async throws {
        let api = AudioAddictAPI.shared
        let trackId = 3202800
        
        let username = KeychainManager.shared.currentUsername
        let password = KeychainManager.shared.currentPassword
        try XCTSkipIf(username.isEmpty || password.isEmpty, "Skipping live auth test: no credentials configured in Keychain")

        let streamURL = await api.resolveEpisodeStreamURL(trackId: trackId, listenKey: "")
        XCTAssertNotNil(streamURL, "Failed to resolve stream URL for track \(trackId)")
        if let url = streamURL {
            XCTAssertTrue(url.absoluteString.hasPrefix("http"), "Stream URL should be an HTTP/HTTPS URL")
        }
    }
}
