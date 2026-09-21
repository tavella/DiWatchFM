import Foundation

struct Channel: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let name: String
    let description: String
    let assetUrl: String?
    let channelFilterIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, key, name, description
        case assetUrl = "asset_url"
        case channelFilterIds = "channel_filter_ids"
    }
}

struct ChannelFilter: Codable, Identifiable, Hashable {
    let id: Int
    let key: String?
    let name: String
    
    static let all = ChannelFilter(id: 0, key: "all", name: "All")
}

enum AudioQuality: String, CaseIterable, Identifiable, Codable {
    case high = "high"
    case standard = "standard"
    case dataSaver = "dataSaver"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .high: return "320k MP3 (High)"
        case .standard: return "128k AAC (Standard)"
        case .dataSaver: return "64k AAC (Data Saver)"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .high: return "320k"
        case .standard: return "128k"
        case .dataSaver: return "64k"
        }
    }
    
    var streamSuffix: String {
        switch self {
        case .high: return "_hi"
        case .standard: return ""
        case .dataSaver: return "_aac"
        }
    }
    
    var plsQualityPath: String {
        switch self {
        case .high: return "premium_high"
        case .standard: return "premium"
        case .dataSaver: return "premium_medium"
        }
    }
    
    var description: String {
        switch self {
        case .high: return "Highest audio fidelity (320 kbps MP3)."
        case .standard: return "Great quality with 60% less data (128 kbps AAC)."
        case .dataSaver: return "Fastest buffer and best on cellular (64 kbps AAC-HE)."
        }
    }
}

enum TrackVoteState: String, Codable {
    case none
    case up
    case down
}

struct TrackVotes: Codable {
    let up: Int?
    let down: Int?
}

struct TrackHistory: Codable, Identifiable {
    let track: String
    let artist: String?
    let title: String?
    let type: String
    let trackId: Int?
    let started: Int?
    let duration: Int?
    let votes: TrackVotes?
    let artUrl: String?
    
    var id: String {
        if let trackId = trackId, let started = started {
            return "\(trackId)-\(started)"
        } else if let trackId = trackId {
            return "\(trackId)-\(track)"
        } else {
            return "\(track)-\(started ?? 0)"
        }
    }
    
    var displayTitle: String {
        if let title = title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return track
    }
    
    var startedDate: Date? {
        guard let started = started, started > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(started))
    }
    
    var relativeTime: String {
        guard let date = startedDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var formattedArtURL: URL? {
        guard let artUrl = artUrl, !artUrl.isEmpty else { return nil }
        if artUrl.hasPrefix("//") {
            return URL(string: "https:\(artUrl)")
        }
        return URL(string: artUrl)
    }
    
    enum CodingKeys: String, CodingKey {
        case track, artist, title, type
        case trackId = "track_id"
        case started, duration
        case votes
        case artUrl = "art_url"
    }
}

struct AuthResponse: Codable {
    let listenKey: String?
    
    enum CodingKeys: String, CodingKey {
        case listenKey = "listen_key"
    }
}

struct MemberSessionResponse: Codable {
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

// MARK: - On-Demand Shows & Mixes

struct Show: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String
    let artistsTagline: String?
    let humanReadableSchedule: [String]?
    let ondemandEpisodeCount: Int?
    let images: ShowImages?
    let channelFilterIds: [Int]?
    let followersCount: Int?
    let active: Bool?

    var imageURL: URL? {
        guard let raw = images?.compact ?? images?.default else { return nil }
        return raw.hasPrefix("//") ? URL(string: "https:\(raw)") : URL(string: raw)
    }

    /// Strip URI templates like `{?size,height,...}` so we get a plain usable URL.
    private func clean(_ s: String?) -> String? {
        guard let s else { return nil }
        if let braceIdx = s.firstIndex(of: "{") {
            return String(s[s.startIndex..<braceIdx])
        }
        return s
    }

    var cleanImageURL: URL? {
        let raw = clean(images?.compact ?? images?.default)
        guard let raw else { return nil }
        return raw.hasPrefix("//") ? URL(string: "https:\(raw)") : URL(string: raw)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, slug, images, active
        case artistsTagline = "artists_tagline"
        case humanReadableSchedule = "human_readable_schedule"
        case ondemandEpisodeCount = "ondemand_episode_count"
        case channelFilterIds = "channel_filter_ids"
        case followersCount = "followers_count"
    }
}

struct ShowImages: Codable, Hashable {
    let `default`: String?
    let compact: String?
    let horizontalBanner: String?

    enum CodingKeys: String, CodingKey {
        case `default`
        case compact
        case horizontalBanner = "horizontal_banner"
    }
}

struct ShowsResponse: Codable {
    let results: [Show]
    let metadata: ShowsMetadata?
}

struct ShowsMetadata: Codable {
    // May contain pagination or facet data — kept for future use
}

struct ShowEpisode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let slug: String?
    let startAt: String?
    let artistsTagline: String?
    let free: Bool?
    let tracks: [EpisodeTrack]?
    let show: EpisodeShow?

    var isFree: Bool { free ?? false }

    var startDate: Date? {
        guard let s = startAt else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    var formattedDate: String {
        guard let d = startDate else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    var primaryTrack: EpisodeTrack? { tracks?.first }

    var displayTitle: String {
        if let t = primaryTrack?.displayTitle, !t.isEmpty { return t }
        if let showName = show?.name, let slug = slug { return "\(showName) \(slug)" }
        return name ?? slug ?? "Episode"
    }

    var displayArtist: String {
        primaryTrack?.displayArtist ?? artistsTagline ?? ""
    }

    var artworkURL: URL? {
        primaryTrack?.artworkURL
    }

    var durationSeconds: Int? { primaryTrack?.length }

    var formattedDuration: String {
        guard let secs = durationSeconds, secs > 0 else { return "" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, slug, tracks, show, free
        case startAt = "start_at"
        case artistsTagline = "artists_tagline"
    }
}

struct EpisodeShow: Codable, Hashable {
    let id: Int
    let name: String
    let slug: String
}

struct EpisodeTrack: Codable, Identifiable, Hashable {
    let id: Int
    let length: Int?
    let displayTitle: String?
    let displayArtist: String?
    let assetUrl: String?

    var artworkURL: URL? {
        guard let raw = assetUrl else { return nil }
        // Strip URI templates
        let clean = raw.contains("{") ? String(raw[raw.startIndex..<raw.firstIndex(of: "{")!]) : raw
        return clean.hasPrefix("//") ? URL(string: "https:\(clean)") : URL(string: clean)
    }

    enum CodingKeys: String, CodingKey {
        case id, length
        case displayTitle = "display_title"
        case displayArtist = "display_artist"
        case assetUrl = "asset_url"
    }
}
