import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.di.watchfm", category: "API")

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case authenticationFailed
}

@Observable
final class AudioAddictAPI {
    static let shared = AudioAddictAPI()
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: config)
    }
    
    func fetchChannels() async throws -> [Channel] {
        guard let url = URL(string: "https://api.audioaddict.com/v1/di/channels") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await self.session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        do {
            let channels = try JSONDecoder().decode([Channel].self, from: data)
            return channels.sorted { $0.name < $1.name }
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func fetchChannelFilters() async throws -> [ChannelFilter] {
        guard let url = URL(string: "https://api.audioaddict.com/v1/di/channel_filters") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await self.session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        do {
            let filters = try JSONDecoder().decode([ChannelFilter].self, from: data)
            return filters.filter { $0.key != "default" && $0.name.lowercased() != "all" && $0.key != "popular" }
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func fetchTrackHistory(channelId: Int) async throws -> [TrackHistory] {
        guard let url = URL(string: "https://api.audioaddict.com/v1/di/track_history/channel/\(channelId)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await self.session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        do {
            let history = try JSONDecoder().decode([TrackHistory].self, from: data)
            return history.filter { $0.type == "track" }
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func fetchLiveMetadata(channelId: Int) async throws -> TrackHistory? {
        let history = try await fetchTrackHistory(channelId: channelId)
        return history.first
    }
    
    func streamURL(for channelKey: String, listenKey: String, quality: AudioQuality = .high) -> URL? {
        return URL(string: "http://prem1.di.fm:80/\(channelKey)\(quality.streamSuffix)?\(listenKey)")
    }
    
    func streamURLs(for channelKey: String, listenKey: String, quality: AudioQuality = .high) async -> [URL] {
        if let plsURL = URL(string: "https://listen.di.fm/\(quality.plsQualityPath)/\(channelKey).pls?\(listenKey)"),
           let (data, response) = try? await self.session.data(from: plsURL),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
           let content = String(data: data, encoding: .utf8) {
            
            var urls: [URL] = []
            for line in content.components(separatedBy: .newlines) {
                if line.hasPrefix("File") && line.contains("=") {
                    let parts = line.split(separator: "=", maxSplits: 1)
                    if parts.count == 2, let parsedURL = URL(string: String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)) {
                        urls.append(parsedURL)
                    }
                }
            }
            if !urls.isEmpty {
                return urls
            }
        }
        
        return [
            URL(string: "http://prem1.di.fm:80/\(channelKey)\(quality.streamSuffix)?\(listenKey)"),
            URL(string: "http://prem4.di.fm:80/\(channelKey)\(quality.streamSuffix)?\(listenKey)")
        ].compactMap { $0 }
    }
    
    func authenticate(username: String, password: String) async throws -> String {
        guard let url = URL(string: "https://api.audioaddict.com/v1/di/member_sessions") else {
            throw APIError.invalidURL
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
                "username": username,
                "password": password
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        logger.info("Sending authentication request for user")
        let (data, response) = try await self.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Authentication failed: non-HTTP response")
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("Authentication failed with HTTP status \(httpResponse.statusCode)")
            throw APIError.authenticationFailed
        }
        
        do {
            let sessionResponse = try JSONDecoder().decode(MemberSessionResponse.self, from: data)
            if let listenKey = sessionResponse.member?.listenKey, !listenKey.isEmpty {
                KeychainManager.shared.saveListenKey(listenKey)
                if let sessionKey = sessionResponse.key, !sessionKey.isEmpty {
                    KeychainManager.shared.saveSessionKey(sessionKey)
                }
                logger.info("Authentication succeeded; tokens stored in Keychain")
                return listenKey
            } else {
                logger.error("No listenKey found in MemberSessionResponse")
                throw APIError.authenticationFailed
            }
        } catch {
            logger.error("Authentication decoding error: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }
    
    func ensureSessionKey() async throws -> String {
        let existing = KeychainManager.shared.currentSessionKey
        if !existing.isEmpty {
            return existing
        }
        
        let username = KeychainManager.shared.currentUsername
        let password = KeychainManager.shared.currentPassword
        guard !username.isEmpty, !password.isEmpty else {
            logger.error("ensureSessionKey: No stored credentials")
            throw APIError.authenticationFailed
        }
        
        logger.info("ensureSessionKey: Authenticating with stored credentials")
        _ = try await authenticate(username: username, password: password)
        let key = KeychainManager.shared.currentSessionKey
        if key.isEmpty {
            logger.error("ensureSessionKey: Succeeded but session key is empty")
            throw APIError.authenticationFailed
        }
        return key
    }
    
    func voteTrack(trackId: Int, channelId: Int, direction: TrackVoteState) async throws {
        let sessionKey = try await ensureSessionKey()
        let action = direction == .up ? "up" : "down"
        guard let url = URL(string: "https://api.audioaddict.com/v1/di/tracks/\(trackId)/vote/\(channelId)/\(action)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionKey, forHTTPHeaderField: "X-Session-Key")
        
        let (_, response) = try await self.session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            // Session expired, re-auth and retry once
            KeychainManager.shared.saveSessionKey("")
            let newKey = try await ensureSessionKey()
            request.setValue(newKey, forHTTPHeaderField: "X-Session-Key")
            _ = try await self.session.data(for: request)
        }
    }
    
    func deleteTrackVote(trackId: Int, channelId: Int) async throws {
        let sessionKey = try await ensureSessionKey()
        guard let url = URL(string: "https://api.audioaddict.com/v1/di/tracks/\(trackId)/vote/\(channelId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(sessionKey, forHTTPHeaderField: "X-Session-Key")
        
        let (_, response) = try await self.session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            // Session expired, re-auth and retry once
            KeychainManager.shared.saveSessionKey("")
            let newKey = try await ensureSessionKey()
            request.setValue(newKey, forHTTPHeaderField: "X-Session-Key")
            _ = try await self.session.data(for: request)
        }
    }

    // MARK: - On-Demand Shows & Episodes

    /// Fetch the full paginated list of shows.
    /// - Parameters:
    ///   - page: 1-indexed page number
    ///   - perPage: items per page (default 50)
    func fetchShows(page: Int = 1, perPage: Int = 50) async throws -> [Show] {
        var components = URLComponents(string: "https://api.audioaddict.com/v1/di/shows")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await self.session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw APIError.invalidResponse
                }

                let decoded = try JSONDecoder().decode(ShowsResponse.self, from: data)
                return decoded.results
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(1_500_000_000))
                }
            }
        }
        throw lastError ?? APIError.invalidResponse
    }

    /// Fetch paginated episodes for a given show.
    func fetchEpisodes(showId: Int, page: Int = 1, perPage: Int = 20) async throws -> [ShowEpisode] {
        var components = URLComponents(string: "https://api.audioaddict.com/v1/di/shows/\(showId)/episodes")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await self.session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw APIError.invalidResponse
                }

                // The episodes endpoint returns a plain JSON array
                let decoder = JSONDecoder()
                return try decoder.decode([ShowEpisode].self, from: data)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(1_500_000_000))
                }
            }
        }
        throw lastError ?? APIError.invalidResponse
    }

    /// Resolve the stream URL for an on-demand episode track.
    ///
    /// Calls `GET /v1/di/tracks/{trackId}?listen_key={key}` with authentication.
    /// - Returns: A playable URL, or `nil` if the track is inaccessible.
    func resolveEpisodeStreamURL(trackId: Int, listenKey: String) async -> URL? {
        // Ensure session key is obtained first if credentials are present
        var sessionKey = KeychainManager.shared.currentSessionKey
        if sessionKey.isEmpty {
            do {
                sessionKey = try await ensureSessionKey()
                print("[resolveEpisodeStreamURL] Acquired session key: \(sessionKey.prefix(8))...")
            } catch {
                print("[resolveEpisodeStreamURL] ensureSessionKey failed: \(error)")
            }
        }

        var components = URLComponents(string: "https://api.audioaddict.com/v1/di/tracks/\(trackId)")!
        var queryItems = [URLQueryItem]()
        let effectiveListenKey = KeychainManager.shared.currentListenKey.isEmpty ? listenKey : KeychainManager.shared.currentListenKey
        if !effectiveListenKey.isEmpty {
            queryItems.append(URLQueryItem(name: "listen_key", value: effectiveListenKey))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let authString = "streams:diradio"
        if let authData = authString.data(using: .utf8) {
            request.setValue("Basic \(authData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        if !sessionKey.isEmpty {
            request.setValue(sessionKey, forHTTPHeaderField: "X-Session-Key")
        }

        let streamKeys = ["stream_url", "stream", "url", "mp3", "aac", "ogg", "hls"]
        let maxRetries = 3

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await self.session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("resolveEpisodeStreamURL: Non-HTTP response")
                    return nil
                }
                logger.debug("resolveEpisodeStreamURL: Track \(trackId) HTTP status \(httpResponse.statusCode) (Attempt \(attempt))")

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check root-level URL keys
                    for key in streamKeys {
                        if let rawURL = json[key] as? String, !rawURL.isEmpty {
                            let cleaned = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
                            if let result = URL(string: cleaned) {
                                logger.debug("resolveEpisodeStreamURL: Resolved URL at root key '\(key)'")
                                return result
                            }
                        }
                    }

                    // Check content dictionary
                    if let content = json["content"] as? [String: Any] {
                        if let assets = content["assets"] as? [[String: Any]] {
                            for asset in assets {
                                if let rawURL = asset["url"] as? String, !rawURL.isEmpty {
                                    let cleaned = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
                                    if let result = URL(string: cleaned) {
                                        logger.debug("resolveEpisodeStreamURL: Resolved URL from assets")
                                        return result
                                    }
                                }
                            }
                        }
                        
                        for key in streamKeys {
                            if let rawURL = content[key] as? String, !rawURL.isEmpty {
                                let cleaned = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
                                if let result = URL(string: cleaned) {
                                    logger.debug("resolveEpisodeStreamURL: Resolved URL at content key '\(key)'")
                                    return result
                                }
                            }
                        }
                        for (key, value) in content {
                            if let rawURL = value as? String, rawURL.contains("://") || rawURL.hasPrefix("//") {
                                let cleaned = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
                                if let result = URL(string: cleaned) {
                                    logger.debug("resolveEpisodeStreamURL: Resolved wildcard content URL at '\(key)'")
                                    return result
                                }
                            }
                        }
                    }

                    // Check preview if available
                    if let preview = json["preview"] as? [String: Any] {
                        for key in streamKeys {
                            if let rawURL = preview[key] as? String, !rawURL.isEmpty {
                                let cleaned = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
                                if let result = URL(string: cleaned) {
                                    logger.debug("resolveEpisodeStreamURL: Resolved preview stream URL")
                                    return result
                                }
                            }
                        }
                    } else if let previewStr = json["preview"] as? String, previewStr.contains("://") || previewStr.hasPrefix("//") {
                        let cleaned = previewStr.hasPrefix("//") ? "https:\(previewStr)" : previewStr
                        if let result = URL(string: cleaned) {
                            logger.debug("resolveEpisodeStreamURL: Resolved preview string URL")
                            return result
                        }
                    }
                }
                
                // If we get here, we successfully connected but didn't find a URL.
                // It's likely an auth issue or unavailable track, so retrying won't help.
                break
                
            } catch {
                logger.error("resolveEpisodeStreamURL: Request failed on attempt \(attempt): \(error.localizedDescription)")
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(1_500_000_000))
                }
            }
        }

        logger.error("resolveEpisodeStreamURL: All attempts exhausted for track \(trackId)")
        return nil
    }
}

