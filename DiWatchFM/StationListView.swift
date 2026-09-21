import SwiftUI
import WatchKit

struct StationListView: View {
    @State private var channels: [Channel] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var filters: [ChannelFilter] = [
        ChannelFilter(id: 0, key: "all", name: "All"),
        ChannelFilter(id: 5, key: "trance", name: "Trance"),
        ChannelFilter(id: 6, key: "house", name: "House"),
        ChannelFilter(id: 8, key: "techno", name: "Techno"),
        ChannelFilter(id: 9, key: "chillout", name: "Chillout"),
        ChannelFilter(id: 15, key: "ambient", name: "Ambient"),
        ChannelFilter(id: 88, key: "deep", name: "Deep"),
        ChannelFilter(id: 118, key: "edm", name: "EDM"),
        ChannelFilter(id: 16, key: "lounge", name: "Lounge"),
        ChannelFilter(id: 65, key: "bass", name: "Bass"),
        ChannelFilter(id: 7, key: "dance", name: "Dance"),
        ChannelFilter(id: 11, key: "vocal", name: "Vocal"),
        ChannelFilter(id: 12, key: "hard", name: "Hard"),
        ChannelFilter(id: 69, key: "synth", name: "Synth"),
        ChannelFilter(id: 19, key: "classic", name: "Classic")
    ]
    @State private var selectedFilter: ChannelFilter? = nil
    @State private var selectedHistoryChannel: Channel? = nil
    @State private var navigateToNowPlaying: Bool = false
    
    private var favorites = FavoritesManager.shared
    
    var filteredChannels: [Channel] {
        var result = channels
        if let filterId = selectedFilter?.id, filterId != 0 {
            result = result.filter { channel in
                channel.channelFilterIds?.contains(filterId) == true
            }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    private var favoriteChannels: [Channel] {
        favorites.favoriteChannels(from: channels)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading Stations...")
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await loadChannels()
                            }
                        }
                        .padding(.top)
                    }
                } else {
                    List {
                        // Genre Filter Pills Row (below search)
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(filters) { filter in
                                        let isSelected = (selectedFilter == nil && filter.id == 0) || (selectedFilter?.id == filter.id)
                                        Text(filter.name)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                isSelected ?
                                                Color.green :
                                                Color.white.opacity(0.14)
                                            )
                                            .foregroundColor(isSelected ? .black : .primary)
                                            .clipShape(Capsule())
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                WKInterfaceDevice.current().play(.click)
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if filter.id == 0 || selectedFilter?.id == filter.id {
                                                        selectedFilter = nil
                                                    } else {
                                                        selectedFilter = filter
                                                    }
                                                }
                                            }
                                    }
                                }
                                .padding(.vertical, 3)
                                .padding(.horizontal, 2)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
                        }

                        // Shows & Mixes entry point
                        Section {
                            NavigationLink(destination: ShowListView()) {
                                HStack {
                                    Image(systemName: "music.note.list")
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Shows & Mixes")
                                            .font(.headline)
                                        Text("On-demand DJ shows and mixes")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        
                        // Now Playing & Recent Tracks Banner (Always visible when playing)
                        let nowPlayingName = WatchAudioPlayer.shared.currentEpisode?.displayTitle
                            ?? WatchAudioPlayer.shared.currentStation?.name
                        if nowPlayingName != nil {
                            Section {
                                Button(action: {
                                    WKInterfaceDevice.current().play(.click)
                                    navigateToNowPlaying = true
                                }) {
                                    HStack {
                                        Image(systemName: "waveform")
                                            .foregroundColor(.green)
                                            .symbolEffect(.variableColor.iterative, isActive: WatchAudioPlayer.shared.state == .playing)
                                        
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Now Playing")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(nowPlayingName ?? "")
                                                .font(.headline)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                if let currentStation = WatchAudioPlayer.shared.currentStation {
                                    NavigationLink(destination: TrackHistoryView(channel: currentStation)) {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundColor(.cyan)
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Track History")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                
                                                if !WatchAudioPlayer.shared.trackTitle.isEmpty {
                                                    Text(WatchAudioPlayer.shared.trackTitle)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                } else {
                                                    Text("Recently played tracks")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        
                        // When a Genre filter is active: show ONLY that genre's stations
                        if let filter = selectedFilter {
                            Section("\(filter.name) (\(filteredChannels.count))") {
                                if filteredChannels.isEmpty {
                                    Text("No stations in \(filter.name)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(filteredChannels) { channel in
                                        stationRow(channel: channel, queue: filteredChannels)
                                    }
                                }
                            }
                        } else {
                            // Default All View: Pinned Favorites Section
                            if !favoriteChannels.isEmpty && searchText.isEmpty {
                                Section(header: Label("Favorites", systemImage: "star.fill").foregroundColor(.yellow)) {
                                    ForEach(favoriteChannels) { channel in
                                        stationRow(channel: channel, queue: favoriteChannels)
                                    }
                                }
                            }
                            
                            // All Stations Section
                            Section("All Stations (\(filteredChannels.count))") {
                                ForEach(filteredChannels) { channel in
                                    stationRow(channel: channel, queue: channels)
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search stations")
                }
            }
            .navigationTitle("DiWatchFM")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToNowPlaying) {
                NowPlayingView()
            }
            .navigationDestination(item: $selectedHistoryChannel) { channel in
                TrackHistoryView(channel: channel)
            }
            .task {
                if channels.isEmpty {
                    await loadChannels()
                }
            }
        }
    }
    
    @ViewBuilder
    private func stationRow(channel: Channel, queue: [Channel]) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            WatchAudioPlayer.shared.play(station: channel, queue: queue)
            navigateToNowPlaying = true
        }) {
            HStack {
                if favorites.isFavorite(channelId: channel.id) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red.opacity(0.85))
                        .font(.caption2)
                }
                
                VStack(alignment: .leading) {
                    Text(channel.name)
                        .font(.headline)
                    Text(channel.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if WatchAudioPlayer.shared.currentStation?.id == channel.id {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                WKInterfaceDevice.current().play(.click)
                selectedHistoryChannel = channel
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tint(.cyan)
        }
    }
    
    private func loadChannels() async {
        isLoading = true
        errorMessage = nil
        do {
            async let channelsTask = AudioAddictAPI.shared.fetchChannels()
            async let filtersTask = AudioAddictAPI.shared.fetchChannelFilters()
            
            let (fetchedChannels, fetchedFilters) = try await (channelsTask, filtersTask)
            self.channels = fetchedChannels
            if !fetchedFilters.isEmpty {
                self.filters = [ChannelFilter.all] + fetchedFilters
            }
            isLoading = false
        } catch {
            if channels.isEmpty {
                do {
                    channels = try await AudioAddictAPI.shared.fetchChannels()
                    isLoading = false
                } catch {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            } else {
                isLoading = false
            }
        }
    }
}

struct TrackHistoryView: View {
    let channel: Channel?
    @Bindable var player = WatchAudioPlayer.shared
    @State private var tracks: [TrackHistory] = []
    @State private var isLoading = false
    
    private var isCurrentStation: Bool {
        guard let channel = channel else { return true }
        return channel.id == player.currentStation?.id
    }
    
    private var displayTracks: [TrackHistory] {
        if isCurrentStation && !player.trackHistory.isEmpty {
            return player.trackHistory
        }
        return tracks
    }
    
    var body: some View {
        Group {
            if isLoading && displayTracks.isEmpty {
                ProgressView("Loading tracks...")
            } else if displayTracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary)
                    Text("No Track History")
                        .font(.headline)
                    Text("Recently played tracks will appear here once loaded.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Refresh") {
                        Task { await loadHistory() }
                    }
                    .padding(.top, 4)
                }
                .padding()
            } else {
                List {
                    ForEach(Array(displayTracks.enumerated()), id: \.element.id) { index, track in
                        TrackHistoryRow(
                            track: track,
                            channelId: channel?.id ?? player.currentStation?.id ?? 0,
                            isNowPlaying: isCurrentStation && index == 0 && (track.trackId == player.currentTrackId || player.currentTrackId == nil)
                        )
                    }
                }
            }
        }
        .navigationTitle(channel?.name ?? "Track History")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadHistory()
        }
        .task {
            if displayTracks.isEmpty {
                await loadHistory()
            }
        }
    }
    
    private func loadHistory() async {
        guard let targetChannel = channel ?? player.currentStation else { return }
        if targetChannel.id == player.currentStation?.id {
            await player.refreshTrackHistory()
        } else {
            isLoading = true
            do {
                tracks = try await AudioAddictAPI.shared.fetchTrackHistory(channelId: targetChannel.id)
                isLoading = false
            } catch {
                isLoading = false
            }
        }
    }
}

struct TrackHistoryRow: View {
    let track: TrackHistory
    let channelId: Int
    let isNowPlaying: Bool
    @Bindable var player = WatchAudioPlayer.shared
    
    private var isLiked: Bool {
        guard let trackId = track.trackId else { return false }
        return player.voteFor(trackId: trackId) == .up
    }
    
    private var isDisliked: Bool {
        guard let trackId = track.trackId else { return false }
        return player.voteFor(trackId: trackId) == .down
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Artwork Thumbnail
            if let artURL = track.formattedArtURL {
                AsyncImage(url: artURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.white.opacity(0.1)
                        Image(systemName: "music.note")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isNowPlaying ? .green : .primary)
                    .lineLimit(2)
                
                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 5) {
                    if isNowPlaying {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform")
                                .symbolEffect(.variableColor.iterative, isActive: player.state == .playing)
                            Text("NOW PLAYING")
                        }
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                    } else if !track.relativeTime.isEmpty {
                        Text(track.relativeTime)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    if let votes = track.votes, let up = votes.up, up > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 7))
                            Text("\(up)")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 2)
            
            // Like Button
            if let trackId = track.trackId {
                Button(action: {
                    WKInterfaceDevice.current().play(.click)
                    player.vote(trackId: trackId, direction: .up)
                }) {
                    Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 11))
                        .foregroundColor(isLiked ? .green : .secondary.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(isLiked ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let trackId = track.trackId {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    player.vote(trackId: trackId, direction: .up)
                } label: {
                    Label("Like", systemImage: isLiked ? "hand.thumbsup.slash" : "hand.thumbsup.fill")
                }
                .tint(.green)
                
                Button {
                    WKInterfaceDevice.current().play(.click)
                    player.vote(trackId: trackId, direction: .down)
                } label: {
                    Label("Dislike", systemImage: isDisliked ? "hand.thumbsdown.slash" : "hand.thumbsdown.fill")
                }
                .tint(.red)
            }
        }
    }
}
