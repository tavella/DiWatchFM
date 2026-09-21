import XCTest
@testable import DiWatchApp

final class ModelsTests: XCTestCase {

    // MARK: - Channel & ChannelFilter Tests

    func testChannelDecoding() throws {
        let json = """
        {
            "id": 42,
            "key": "trance",
            "name": "Trance",
            "description": "Uplifting beats",
            "asset_url": "//assets.di.fm/station.jpg",
            "channel_filter_ids": [1, 2, 3]
        }
        """.data(using: .utf8)!

        let channel = try JSONDecoder().decode(Channel.self, from: json)
        XCTAssertEqual(channel.id, 42)
        XCTAssertEqual(channel.key, "trance")
        XCTAssertEqual(channel.name, "Trance")
        XCTAssertEqual(channel.description, "Uplifting beats")
        XCTAssertEqual(channel.assetUrl, "//assets.di.fm/station.jpg")
        XCTAssertEqual(channel.channelFilterIds, [1, 2, 3])
    }

    func testChannelFilterDecodingAndStaticAll() throws {
        let json = """
        {
            "id": 10,
            "key": "edm",
            "name": "EDM"
        }
        """.data(using: .utf8)!

        let filter = try JSONDecoder().decode(ChannelFilter.self, from: json)
        XCTAssertEqual(filter.id, 10)
        XCTAssertEqual(filter.key, "edm")
        XCTAssertEqual(filter.name, "EDM")

        let allFilter = ChannelFilter.all
        XCTAssertEqual(allFilter.id, 0)
        XCTAssertEqual(allFilter.key, "all")
        XCTAssertEqual(allFilter.name, "All")
    }

    // MARK: - AudioQuality Tests

    func testAudioQualityProperties() {
        for quality in AudioQuality.allCases {
            XCTAssertEqual(quality.id, quality.rawValue)
            XCTAssertFalse(quality.title.isEmpty)
            XCTAssertFalse(quality.shortTitle.isEmpty)
            XCTAssertFalse(quality.description.isEmpty)
        }

        XCTAssertEqual(AudioQuality.high.streamSuffix, "_hi")
        XCTAssertEqual(AudioQuality.standard.streamSuffix, "")
        XCTAssertEqual(AudioQuality.dataSaver.streamSuffix, "_aac")

        XCTAssertEqual(AudioQuality.high.plsQualityPath, "premium_high")
        XCTAssertEqual(AudioQuality.standard.plsQualityPath, "premium")
        XCTAssertEqual(AudioQuality.dataSaver.plsQualityPath, "premium_medium")
    }

    // MARK: - TrackVoteState Tests

    func testTrackVoteStateValues() {
        XCTAssertEqual(TrackVoteState.none.rawValue, "none")
        XCTAssertEqual(TrackVoteState.up.rawValue, "up")
        XCTAssertEqual(TrackVoteState.down.rawValue, "down")
    }

    // MARK: - TrackHistory Tests

    func testTrackHistoryDecodingAndComputedProperties() throws {
        let json = """
        {
            "track": "Armin van Buuren - Communication",
            "artist": "Armin van Buuren",
            "title": "Communication",
            "type": "track",
            "track_id": 1001,
            "started": 1700000000,
            "duration": 360,
            "votes": {
                "up": 150,
                "down": 3
            },
            "art_url": "//assets.di.fm/art/1001.jpg"
        }
        """.data(using: .utf8)!

        let history = try JSONDecoder().decode(TrackHistory.self, from: json)
        XCTAssertEqual(history.trackId, 1001)
        XCTAssertEqual(history.id, "1001-1700000000")
        XCTAssertEqual(history.displayTitle, "Communication")
        XCTAssertEqual(history.votes?.up, 150)
        XCTAssertEqual(history.votes?.down, 3)
        XCTAssertEqual(history.startedDate, Date(timeIntervalSince1970: 1700000000))
        XCTAssertFalse(history.relativeTime.isEmpty)
        XCTAssertEqual(history.formattedArtURL, URL(string: "https://assets.di.fm/art/1001.jpg"))
    }

    func testTrackHistoryFallbackIdAndDisplayTitle() {
        let item1 = TrackHistory(
            track: "Default Track",
            artist: nil,
            title: "   ",
            type: "track",
            trackId: 2002,
            started: nil,
            duration: nil,
            votes: nil,
            artUrl: "https://example.com/cover.png"
        )
        XCTAssertEqual(item1.id, "2002-Default Track")
        XCTAssertEqual(item1.displayTitle, "Default Track")
        XCTAssertNil(item1.startedDate)
        XCTAssertEqual(item1.relativeTime, "")
        XCTAssertEqual(item1.formattedArtURL, URL(string: "https://example.com/cover.png"))

        let item2 = TrackHistory(
            track: "Raw Title Only",
            artist: nil,
            title: nil,
            type: "track",
            trackId: nil,
            started: 1600000000,
            duration: nil,
            votes: nil,
            artUrl: nil
        )
        XCTAssertEqual(item2.id, "Raw Title Only-1600000000")
        XCTAssertEqual(item2.displayTitle, "Raw Title Only")
        XCTAssertNil(item2.formattedArtURL)
    }

    // MARK: - AuthResponse & MemberSessionResponse

    func testAuthResponseDecoding() throws {
        let json = """
        {
            "listen_key": "sample_listen_key_abc"
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(AuthResponse.self, from: json)
        XCTAssertEqual(res.listenKey, "sample_listen_key_abc")
    }

    func testMemberSessionResponseDecoding() throws {
        let json = """
        {
            "key": "session_key_xyz",
            "member": {
                "listen_key": "listen_key_123",
                "user_type": "premium",
                "email": "listener@example.com"
            }
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(MemberSessionResponse.self, from: json)
        XCTAssertEqual(res.key, "session_key_xyz")
        XCTAssertEqual(res.member?.listenKey, "listen_key_123")
        XCTAssertEqual(res.member?.userType, "premium")
        XCTAssertEqual(res.member?.email, "listener@example.com")
    }

    // MARK: - Show & ShowImages Tests

    func testShowDecodingAndImageURLTemplates() throws {
        let json = """
        {
            "id": 99,
            "name": "A State of Trance",
            "slug": "asot",
            "artists_tagline": "Armin van Buuren",
            "human_readable_schedule": ["Thursdays at 20:00 CET"],
            "ondemand_episode_count": 500,
            "images": {
                "default": "https://assets.di.fm/shows/asot_default.jpg{?size,height}",
                "compact": "//assets.di.fm/shows/asot_compact.jpg{?size}"
            },
            "channel_filter_ids": [1, 5],
            "followers_count": 25000,
            "active": true
        }
        """.data(using: .utf8)!

        let show = try JSONDecoder().decode(Show.self, from: json)
        XCTAssertEqual(show.id, 99)
        XCTAssertEqual(show.name, "A State of Trance")
        XCTAssertEqual(show.slug, "asot")
        XCTAssertEqual(show.artistsTagline, "Armin van Buuren")
        XCTAssertEqual(show.humanReadableSchedule?.first, "Thursdays at 20:00 CET")
        XCTAssertEqual(show.ondemandEpisodeCount, 500)
        XCTAssertEqual(show.channelFilterIds, [1, 5])
        XCTAssertEqual(show.followersCount, 25000)
        XCTAssertEqual(show.active, true)

        // Raw imageURL uses compact first, preserves template
        XCTAssertEqual(show.imageURL, URL(string: "https://assets.di.fm/shows/asot_compact.jpg{?size}"))

        // cleanImageURL strips {?size} and prefixes https:
        XCTAssertEqual(show.cleanImageURL, URL(string: "https://assets.di.fm/shows/asot_compact.jpg"))
    }

    func testShowImageURLFallbackToDefault() {
        let images = ShowImages(
            default: "https://assets.di.fm/shows/default.png",
            compact: nil,
            horizontalBanner: nil
        )
        let show = Show(
            id: 1,
            name: "Test Show",
            slug: "test-show",
            artistsTagline: nil,
            humanReadableSchedule: nil,
            ondemandEpisodeCount: nil,
            images: images,
            channelFilterIds: nil,
            followersCount: nil,
            active: true
        )
        XCTAssertEqual(show.imageURL, URL(string: "https://assets.di.fm/shows/default.png"))
        XCTAssertEqual(show.cleanImageURL, URL(string: "https://assets.di.fm/shows/default.png"))
    }

    // MARK: - ShowEpisode & EpisodeTrack Tests

    func testShowEpisodeDecodingAndFormatting() throws {
        let json = """
        {
            "id": 501,
            "name": "ASOT Episode 1100",
            "slug": "1100",
            "start_at": "2024-03-15T19:00:00.000Z",
            "artists_tagline": "Armin van Buuren",
            "free": true,
            "show": {
                "id": 99,
                "name": "A State of Trance",
                "slug": "asot"
            },
            "tracks": [
                {
                    "id": 8801,
                    "length": 7320,
                    "display_title": "A State of Trance 1100",
                    "display_artist": "Armin van Buuren",
                    "asset_url": "//assets.di.fm/episodes/1100.jpg{?size}"
                }
            ]
        }
        """.data(using: .utf8)!

        let episode = try JSONDecoder().decode(ShowEpisode.self, from: json)
        XCTAssertEqual(episode.id, 501)
        XCTAssertEqual(episode.isFree, true)
        XCTAssertNotNil(episode.startDate)
        XCTAssertFalse(episode.formattedDate.isEmpty)
        XCTAssertEqual(episode.displayTitle, "A State of Trance 1100")
        XCTAssertEqual(episode.displayArtist, "Armin van Buuren")
        XCTAssertEqual(episode.durationSeconds, 7320)
        XCTAssertEqual(episode.formattedDuration, "2h 2m") // 7320s = 2h 2m

        // Track artwork URL cleans URI template and prepends https:
        XCTAssertEqual(episode.artworkURL, URL(string: "https://assets.di.fm/episodes/1100.jpg"))
    }

    func testShowEpisodeDurationAndTitleFallbacks() {
        // Episode under 1 hour duration
        let trackUnder1h = EpisodeTrack(
            id: 1,
            length: 2700, // 45m
            displayTitle: nil,
            displayArtist: nil,
            assetUrl: "https://assets.di.fm/episodes/short.jpg"
        )
        let episode1 = ShowEpisode(
            id: 2,
            name: nil,
            slug: "ep-45",
            startAt: "2024-03-15T19:00:00Z",
            artistsTagline: "Host Tagline",
            free: nil,
            tracks: [trackUnder1h],
            show: EpisodeShow(id: 10, name: "Short Show", slug: "short")
        )

        XCTAssertFalse(episode1.isFree)
        XCTAssertEqual(episode1.formattedDuration, "45m")
        XCTAssertEqual(episode1.displayTitle, "Short Show ep-45")
        XCTAssertEqual(episode1.displayArtist, "Host Tagline")

        // Episode with no tracks and fallback title "Episode"
        let episode2 = ShowEpisode(
            id: 3,
            name: nil,
            slug: nil,
            startAt: nil,
            artistsTagline: nil,
            free: nil,
            tracks: nil,
            show: nil
        )
        XCTAssertEqual(episode2.formattedDuration, "")
        XCTAssertEqual(episode2.displayTitle, "Episode")
        XCTAssertEqual(episode2.displayArtist, "")
        XCTAssertNil(episode2.startDate)
        XCTAssertEqual(episode2.formattedDate, "")
    }
}
