import SwiftUI
import WatchKit

struct EpisodeListView: View {
    let show: Show

    @State private var episodes: [ShowEpisode] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var navigateToNowPlaying = false
    private let perPage = 20

    var body: some View {
        Group {
            if isLoading && episodes.isEmpty {
                ProgressView("Loading Episodes...")
            } else if let error = errorMessage, episodes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                    Text("Failed to load")
                        .font(.headline)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadEpisodes(reset: true) }
                    }
                    .padding(.top, 4)
                }
                .padding()
            } else {
                List {
                    ForEach(episodes) { episode in
                        EpisodeRow(episode: episode) {
                            playEpisode(episode)
                        }
                    }

                    // Load-more trigger
                    if hasMorePages {
                        if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Color.clear
                                .frame(height: 1)
                                .listRowBackground(Color.clear)
                                .onAppear {
                                    Task { await loadEpisodes(reset: false) }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(show.name)
        .navigationDestination(isPresented: $navigateToNowPlaying) {
            NowPlayingView()
        }
        .task {
            if episodes.isEmpty {
                await loadEpisodes(reset: true)
            }
        }
    }

    private func playEpisode(_ episode: ShowEpisode) {
        guard let track = episode.primaryTrack else {
            return
        }

        // Check premium gating — warn but still attempt
        if !episode.isFree {
            let hasCredentials = !KeychainManager.shared.currentSessionKey.isEmpty ||
                (!KeychainManager.shared.currentUsername.isEmpty && !KeychainManager.shared.currentPassword.isEmpty)
            if !hasCredentials {
                // Show won't play without auth — WatchAudioPlayer will surface the error
                WatchAudioPlayer.shared.lastErrorMessage = "Premium episode. Add credentials in Settings to unlock."
            }
        }

        WKInterfaceDevice.current().play(.click)
        WatchAudioPlayer.shared.playEpisode(episode, track: track)
        navigateToNowPlaying = true
    }

    private func loadEpisodes(reset: Bool) async {
        if reset {
            isLoading = true
            currentPage = 1
            hasMorePages = true
        } else {
            guard !isLoadingMore, hasMorePages else { return }
            isLoadingMore = true
        }

        do {
            let fetched = try await AudioAddictAPI.shared.fetchEpisodes(showId: show.id, page: currentPage, perPage: perPage)
            await MainActor.run {
                if reset {
                    episodes = fetched
                } else {
                    let existingIDs = Set(episodes.map { $0.id })
                    episodes.append(contentsOf: fetched.filter { !existingIDs.contains($0.id) })
                }
                hasMorePages = fetched.count == perPage
                currentPage += 1
                isLoading = false
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                isLoadingMore = false
            }
        }
    }
}

// MARK: - Episode Row

struct EpisodeRow: View {
    let episode: ShowEpisode
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 8) {
                // Artwork
                AsyncImage(url: episode.artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.white.opacity(0.1)
                        Image(systemName: "waveform")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)

                    if !episode.displayArtist.isEmpty {
                        Text(episode.displayArtist)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 5) {
                        if !episode.formattedDate.isEmpty {
                            Text(episode.formattedDate)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.8))
                        }

                        if !episode.formattedDuration.isEmpty {
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(episode.formattedDuration)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                }

                Spacer(minLength: 2)

                // FREE / PREMIUM badge
                VStack {
                    if episode.isFree {
                        Text("FREE")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.85))
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
