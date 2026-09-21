import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI
import Network
import OSLog
import WatchKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.di.watchfm", category: "AudioPlayer")

enum PlaybackState {
    case stopped
    case buffering
    case playing
    case paused
}

@Observable
@MainActor
final class WatchAudioPlayer {
    static let shared = WatchAudioPlayer()
    
    var currentStation: Channel?
    var currentEpisode: ShowEpisode?   // non-nil when playing on-demand
    var trackTitle: String = ""
    var artistName: String = ""
    var currentTrackId: Int?
    var currentTrackVote: TrackVoteState = .none
    var state: PlaybackState = .stopped
    var currentArtworkURL: URL?
    var trackHistory: [TrackHistory] = []
    var isLoadingHistory: Bool = false
    var lastErrorMessage: String? = nil
    
    var currentQuality: AudioQuality = .high {
        didSet {
            UserDefaults.standard.set(currentQuality.rawValue, forKey: audioQualityKey)
        }
    }
    private let audioQualityKey = "com.di.watchfm.audioQuality"
    
    private var trackVotes: [Int: TrackVoteState] = [:]
    private let trackVotesKey = "com.di.watchfm.trackVotes"
    
    private var player: AVPlayer?
    private var metadataTimer: Timer?
    private var queue: [Channel] = []
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var bufferLikelyToKeepUpObservation: NSKeyValueObservation?
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var stallWatchdogTimer: Timer?
    private var playerItemStalledObserver: Any?
    private var playerItemFailedObserver: Any?
    private var availableStreamURLs: [URL] = []
    private var currentStreamIndex: Int = 0
    private var streamURLsTask: Task<Void, Never>?
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    
    // Network path monitoring & buffering stabilization
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "com.di.watchfm.networkmonitor")
    private var currentInterfaceType: NWInterface.InterfaceType = .other
    private var isNetworkConnected: Bool = true
    private var bufferDebounceTask: Task<Void, Never>?
    
    init() {
        if let savedQualityStr = UserDefaults.standard.string(forKey: audioQualityKey),
           let savedQuality = AudioQuality(rawValue: savedQualityStr) {
            self.currentQuality = savedQuality
        }
        loadVotes()
        setupAudioSession()
        setupRemoteTransportControls()
        setupNotifications()
        setupNetworkMonitoring()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            print("Failed to set longFormAudio policy, falling back to default: \(error)")
            do {
                try session.setCategory(.playback, mode: .default, policy: .default)
            } catch {
                print("Failed to set up audio session: \(error)")
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            if reason == .oldDeviceUnavailable {
                self?.pause()
            }
        }
        
        if #available(watchOS 27.0, iOS 27.0, *) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("AVAudioSessionDidBecomeInactiveNotification"), object: nil, queue: .main) { [weak self] _ in
                self?.pause()
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("AVAudioSessionResumptionRecommendationNotification"), object: nil, queue: .main) { [weak self] _ in
                AVAudioSession.sharedInstance().activate(options: []) { _, _ in }
                self?.player?.playImmediately(atRate: 1.0)
                self?.state = .playing
            }
        } else {
            NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                
                if type == .began {
                    self?.pause()
                } else if type == .ended {
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            AVAudioSession.sharedInstance().activate(options: []) { _, _ in }
                            self?.player?.playImmediately(atRate: 1.0)
                            self?.state = .playing
                        }
                    }
                }
            }
        }
    }
    
    func setAudioQuality(_ quality: AudioQuality) {
        guard quality != self.currentQuality else { return }
        self.currentQuality = quality
        if (state == .playing || state == .buffering), let station = currentStation {
            print("Audio quality changed to \(quality.title), reloading stream...")
            play(station: station)
        }
    }
    
    func play(station: Channel, queue: [Channel] = []) {
        self.currentStation = station
        self.currentEpisode = nil   // clear any on-demand episode
        if !queue.isEmpty {
            self.queue = queue
        }
        
        self.trackTitle = ""
        self.artistName = ""
        self.currentTrackId = nil
        self.currentTrackVote = .none
        self.trackHistory = []
        self.currentArtworkURL = buildImageURL(from: station.assetUrl)
        self.retryCount = 0
        self.lastErrorMessage = nil
        
        let session = AVAudioSession.sharedInstance()
        session.activate(options: []) { [weak self] success, error in
            if !success {
                let desc = error?.localizedDescription ?? "Route unavailable"
                print("Audio session activation error: \(desc)")
                Task { @MainActor in
                    self?.lastErrorMessage = "Connect headphones / route"
                }
            }
        }
        
        let listenKey = KeychainManager.shared.currentListenKey
        guard let url = AudioAddictAPI.shared.streamURL(for: station.key, listenKey: listenKey, quality: currentQuality) else { return }
        
        self.availableStreamURLs = [url]
        self.currentStreamIndex = 0
        loadAndPlay(url: url)
        
        // Also fetch live PLS in background for load-balanced server pool if available
        streamURLsTask?.cancel()
        streamURLsTask = Task {
            let urls = await AudioAddictAPI.shared.streamURLs(for: station.key, listenKey: listenKey, quality: self.currentQuality)
            if !Task.isCancelled && !urls.isEmpty {
                await MainActor.run {
                    self.availableStreamURLs = urls
                }
            }
        }
    }
    
    // MARK: - On-Demand Episode Playback

    /// Play an on-demand show episode.
    /// - Parameters:
    ///   - episode: The episode metadata to display in Now Playing.
    ///   - track: The specific `EpisodeTrack` to stream (usually `episode.primaryTrack`).
    func playEpisode(_ episode: ShowEpisode, track: EpisodeTrack) {
        // Tear down any live stream
        currentStation = nil
        currentEpisode = episode

        // Stop current playback immediately to avoid playing the old stream while loading
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        trackTitle = episode.displayTitle
        artistName = episode.displayArtist
        currentTrackId = track.id
        currentTrackVote = .none
        trackHistory = []
        currentArtworkURL = episode.artworkURL
        retryCount = 0
        lastErrorMessage = nil
        state = .buffering

        stopMetadataPolling()

        let listenKey = KeychainManager.shared.currentListenKey

        // Resolve the real stream URL asynchronously via the API
        Task { @MainActor in
            let streamURL = await AudioAddictAPI.shared.resolveEpisodeStreamURL(
                trackId: track.id,
                listenKey: listenKey
            )

            guard self.currentTrackId == track.id else {
                logger.debug("Track changed while resolving stream URL, ignoring")
                return
            }

            guard let url = streamURL else {
                let hasCredentials = !KeychainManager.shared.currentSessionKey.isEmpty ||
                    (!KeychainManager.shared.currentUsername.isEmpty && !KeychainManager.shared.currentPassword.isEmpty)
                if !hasCredentials {
                    self.lastErrorMessage = "Premium episode. Add username & password in Settings to unlock."
                } else if episode.isFree {
                    self.lastErrorMessage = "Could not load stream. Check your Listen Key in Settings."
                } else {
                    self.lastErrorMessage = "Unable to unlock episode. Check DI.FM subscription."
                }
                self.state = .stopped
                return
            }

            let session = AVAudioSession.sharedInstance()
            session.activate(options: []) { [weak self] success, error in
                if !success {
                    Task { @MainActor in
                        self?.lastErrorMessage = error?.localizedDescription ?? "Audio route unavailable"
                    }
                }
            }

            self.availableStreamURLs = [url]
            self.currentStreamIndex = 0
            self.loadAndPlay(url: url)
            self.updateNowPlayingInfo()
        }
    }

    private func reconnectNextStream() {
        guard currentStation != nil || currentEpisode != nil else { return }
        
        guard retryCount < maxRetries else {
            let name = currentStation?.name ?? currentEpisode?.displayTitle ?? "stream"
            print("Max retry count (\(maxRetries)) reached for \(name). Halting reconnect loop.")
            resetStallWatchdog()
            state = .paused
            if lastErrorMessage == nil {
                lastErrorMessage = "Playback stopped. Tap play to retry."
            }
            return
        }
        retryCount += 1
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self = self else { return }
            
            if let station = self.currentStation {
                if self.availableStreamURLs.count > 1 {
                    self.currentStreamIndex = (self.currentStreamIndex + 1) % self.availableStreamURLs.count
                    let nextUrl = self.availableStreamURLs[self.currentStreamIndex]
                    print("Failover (attempt \(self.retryCount)/\(self.maxRetries)): Switching to alternate stream server \(nextUrl.host ?? "")")
                    self.loadAndPlay(url: nextUrl)
                } else {
                    print("Failover (attempt \(self.retryCount)/\(self.maxRetries)): Retrying station \(station.name)")
                    if let url = self.availableStreamURLs.first ?? AudioAddictAPI.shared.streamURL(for: station.key, listenKey: KeychainManager.shared.currentListenKey, quality: self.currentQuality) {
                        self.loadAndPlay(url: url)
                    }
                }
            } else if let episode = self.currentEpisode {
                print("Failover (attempt \(self.retryCount)/\(self.maxRetries)): Retrying episode \(episode.displayTitle)")
                if let url = self.availableStreamURLs.first {
                    self.loadAndPlay(url: url)
                }
            }
        }
    }
    
    private func resetStallWatchdog() {
        stallWatchdogTimer?.invalidate()
        stallWatchdogTimer = nil
    }
    
    private func armStallWatchdog() {
        stallWatchdogTimer?.invalidate()
        stallWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
            guard let self = self, self.state == .buffering else { return }
            logger.info("Watchdog: Buffering stalled for 12s, nudging player...")
            self.player?.play()
            
            // If still buffering after another 5s, failover to alternate server
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self = self, self.state == .buffering else { return }
                logger.info("Watchdog: Still stuck in buffer, failing over...")
                self.reconnectNextStream()
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isConnected = path.status == .satisfied
            let newInterface: NWInterface.InterfaceType
            if path.usesInterfaceType(.wifi) {
                newInterface = .wifi
            } else if path.usesInterfaceType(.cellular) {
                newInterface = .cellular
            } else {
                newInterface = .other
            }
            
            Task { @MainActor in
                let previousInterface = self.currentInterfaceType
                let wasConnected = self.isNetworkConnected
                
                self.currentInterfaceType = newInterface
                self.isNetworkConnected = isConnected
                
                let interfaceChanged = previousInterface != .other && previousInterface != newInterface
                let reconnected = !wasConnected && isConnected
                
                if (interfaceChanged || reconnected) && (self.state == .buffering || self.state == .playing) {
                    logger.info("Network path switched to \(String(describing: newInterface)), re-establishing active stream...")
                    self.reconnectCurrentStream()
                }
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }
    
    func reconnectCurrentStream() {
        guard currentStation != nil || currentEpisode != nil else { return }
        let currentUrl = availableStreamURLs.indices.contains(currentStreamIndex) ? availableStreamURLs[currentStreamIndex] : availableStreamURLs.first
        if let url = currentUrl {
            loadAndPlay(url: url)
        }
    }
    
    private func transitionToBuffering() {
        bufferDebounceTask?.cancel()
        if state != .buffering {
            logger.debug("State transition -> .buffering")
            state = .buffering
            armStallWatchdog()
            updateNowPlayingInfo()
        }
    }
    
    private func debounceTransitionToPlaying() {
        bufferDebounceTask?.cancel()
        bufferDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, self.state == .buffering else { return }
            
            // Verify playback can continue smoothly
            if self.player?.timeControlStatus == .playing || self.player?.currentItem?.isPlaybackLikelyToKeepUp == true {
                logger.debug("Buffer stabilized; state transition -> .playing")
                self.state = .playing
                self.lastErrorMessage = nil
                self.retryCount = 0
                self.resetStallWatchdog()
                self.updateNowPlayingInfo()
            }
        }
    }
    
    private func loadAndPlay(url: URL) {
        state = .buffering
        armStallWatchdog()
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // 5-second forward buffer prevents underruns on fluctuating or fringe connections
        playerItem.preferredForwardBufferDuration = 5.0
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Remove previous item observers
        if let observer = playerItemStalledObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = playerItemFailedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Recover on stall notification with buffering hysteresis
        playerItemStalledObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.playbackStalledNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            logger.debug("AVPlayerItemPlaybackStalled: Handling stall with buffering hysteresis")
            self?.transitionToBuffering()
        }
        
        // Recover on live stream disconnect or failure
        playerItemFailedObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            logger.info("AVPlayerItemFailedToPlayToEndTime: Failing over to next server...")
            self?.reconnectNextStream()
        }
        
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    logger.debug("AVPlayerItem ready to play, starting playback...")
                    self?.player?.play()
                    self?.debounceTransitionToPlaying()
                case .failed:
                    let err = item.error?.localizedDescription ?? "Stream connection failed"
                    logger.error("AVPlayerItem failed with error: \(err)")
                    self?.lastErrorMessage = err
                    self?.reconnectNextStream()
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = playerItem.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            if item.isPlaybackBufferEmpty {
                logger.debug("Buffer empty notification")
                Task { @MainActor in
                    self?.transitionToBuffering()
                }
            }
        }
        
        bufferLikelyToKeepUpObservation?.invalidate()
        bufferLikelyToKeepUpObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            if item.isPlaybackLikelyToKeepUp {
                Task { @MainActor in
                    if self?.state == .buffering {
                        logger.debug("Buffer likely to keep up; debouncing transition to playing")
                        self?.debounceTransitionToPlaying()
                    }
                }
            }
        }
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = true
            player?.volume = 1.0
        } else {
            player?.automaticallyWaitsToMinimizeStalling = true
            player?.replaceCurrentItem(with: playerItem)
            player?.volume = 1.0
        }
        
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = player?.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
            Task { @MainActor in
                switch player.timeControlStatus {
                case .paused:
                    if let error = player.currentItem?.error {
                        let err = error.localizedDescription
                        logger.error("Player item failed: \(err)")
                        self?.lastErrorMessage = err
                        self?.reconnectNextStream()
                    } else if self?.state != .buffering {
                        self?.bufferDebounceTask?.cancel()
                        self?.state = .paused
                        self?.resetStallWatchdog()
                    }
                case .waitingToPlayAtSpecifiedRate:
                    self?.transitionToBuffering()
                case .playing:
                    self?.debounceTransitionToPlaying()
                @unknown default:
                    break
                }
                self?.updateNowPlayingInfo()
            }
        }
        
        player?.play()
        fetchMetadata()
        startMetadataPolling()
    }
    
    func pause() {
        bufferDebounceTask?.cancel()
        resetStallWatchdog()
        player?.pause()
        // Tear down the live stream item so it stops buffering and using data
        if currentStation != nil {
            player?.replaceCurrentItem(with: nil)
        }
        state = .paused
        stopMetadataPolling()
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if state == .playing || state == .buffering {
            pause()
        } else if let station = currentStation {
            retryCount = 0
            lastErrorMessage = nil
            // Since pause() removes the item for live streams, we must check currentItem
            if player?.currentItem != nil {
                AVAudioSession.sharedInstance().activate(options: []) { _, _ in }
                player?.playImmediately(atRate: 1.0)
                state = .playing
                startMetadataPolling()
                updateNowPlayingInfo()
            } else {
                play(station: station)
            }
        }
    }
    
    func skipForward() {
        guard let current = currentStation, !queue.isEmpty else { return }
        if let currentIndex = queue.firstIndex(of: current) {
            let nextIndex = (currentIndex + 1) % queue.count
            play(station: queue[nextIndex], queue: queue)
        }
    }
    
    func skipBackward() {
        guard let current = currentStation, !queue.isEmpty else { return }
        if let currentIndex = queue.firstIndex(of: current) {
            let prevIndex = (currentIndex - 1 + queue.count) % queue.count
            play(station: queue[prevIndex], queue: queue)
        }
    }
    
    func vote(trackId: Int, direction: TrackVoteState) {
        guard let station = currentStation else { return }
        let currentVote = trackVotes[trackId] ?? .none
        
        if currentVote == direction {
            currentTrackVote = (currentTrackId == trackId) ? .none : currentTrackVote
            trackVotes.removeValue(forKey: trackId)
            saveVotes()
            Task {
                try? await AudioAddictAPI.shared.deleteTrackVote(trackId: trackId, channelId: station.id)
            }
        } else {
            if currentTrackId == trackId {
                currentTrackVote = direction
            }
            trackVotes[trackId] = direction
            saveVotes()
            Task {
                try? await AudioAddictAPI.shared.voteTrack(trackId: trackId, channelId: station.id, direction: direction)
            }
        }
    }
    
    func voteFor(trackId: Int) -> TrackVoteState {
        return trackVotes[trackId] ?? .none
    }
    
    func toggleVoteUp() {
        guard let trackId = currentTrackId else { return }
        vote(trackId: trackId, direction: .up)
    }
    
    func toggleVoteDown() {
        guard let trackId = currentTrackId else { return }
        vote(trackId: trackId, direction: .down)
    }
    
    private func loadVotes() {
        if let data = UserDefaults.standard.dictionary(forKey: trackVotesKey) as? [String: String] {
            var votes: [Int: TrackVoteState] = [:]
            for (key, val) in data {
                if let id = Int(key), let state = TrackVoteState(rawValue: val) {
                    votes[id] = state
                }
            }
            self.trackVotes = votes
        }
    }
    
    private func saveVotes() {
        var dict: [String: String] = [:]
        for (id, state) in trackVotes {
            dict[String(id)] = state.rawValue
        }
        UserDefaults.standard.set(dict, forKey: trackVotesKey)
    }
    
    private func fetchMetadata() {
        guard let station = currentStation else { return }
        Task {
            do {
                let history = try await AudioAddictAPI.shared.fetchTrackHistory(channelId: station.id)
                await MainActor.run {
                    self.trackHistory = history
                    if let metadata = history.first {
                        self.trackTitle = metadata.displayTitle
                        self.artistName = metadata.artist ?? "Unknown Artist"
                        self.currentTrackId = metadata.trackId
                        if let trackId = metadata.trackId {
                            self.currentTrackVote = self.trackVotes[trackId] ?? .none
                        } else {
                            self.currentTrackVote = .none
                        }
                        
                        self.currentArtworkURL = metadata.formattedArtURL ?? self.buildImageURL(from: station.assetUrl)
                        self.updateNowPlayingInfo()
                    }
                }
            } catch {
                print("Error fetching metadata: \(error)")
            }
        }
    }
    
    func refreshTrackHistory() async {
        guard let station = currentStation else { return }
        await MainActor.run { self.isLoadingHistory = true }
        do {
            let history = try await AudioAddictAPI.shared.fetchTrackHistory(channelId: station.id)
            await MainActor.run {
                self.trackHistory = history
                self.isLoadingHistory = false
            }
        } catch {
            print("Error refreshing track history: \(error)")
            await MainActor.run { self.isLoadingHistory = false }
        }
    }
    
    private func startMetadataPolling() {
        metadataTimer?.invalidate()
        metadataTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard WKApplication.shared().applicationState != .background else { return }
            self?.fetchMetadata()
        }
    }
    
    private func stopMetadataPolling() {
        metadataTimer?.invalidate()
        metadataTimer = nil
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        let isLive = currentEpisode == nil

        nowPlayingInfo[MPMediaItemPropertyTitle] = trackTitle.isEmpty ? (currentStation?.name ?? "DI.FM") : trackTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = artistName.isEmpty ? "DI.FM" : artistName
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = isLive ? currentStation?.name : currentEpisode?.show?.name
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLive

        if !isLive, let secs = currentEpisode?.durationSeconds {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = secs
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.state == .paused {
                self.player?.play()
                self.state = .playing
                self.startMetadataPolling()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.state == .playing || self.state == .buffering {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [unowned self] event in
            self.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            self.skipForward()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            self.skipBackward()
            return .success
        }
        
        commandCenter.likeCommand.addTarget { [unowned self] _ in
            self.toggleVoteUp()
            return .success
        }
        
        commandCenter.dislikeCommand.addTarget { [unowned self] _ in
            self.toggleVoteDown()
            return .success
        }
    }
    
    private func buildImageURL(from urlString: String?) -> URL? {
        guard let urlString = urlString else { return nil }
        if urlString.hasPrefix("//") {
            return URL(string: "https:\(urlString)")
        }
        return URL(string: urlString)
    }
}
