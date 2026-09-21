import SwiftUI
import WatchKit

struct ShowListView: View {
    @State private var shows: [Show] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var currentPage = 1
    @State private var hasMorePages = true
    private let perPage = 50

    var filteredShows: [Show] {
        guard !searchText.isEmpty else { return shows }
        return shows.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.artistsTagline?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if isLoading && shows.isEmpty {
                ProgressView("Loading Shows...")
            } else if let error = errorMessage, shows.isEmpty {
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
                        Task { await loadShows(reset: true) }
                    }
                    .padding(.top, 4)
                }
                .padding()
            } else {
                List {
                    ForEach(filteredShows) { show in
                        NavigationLink(destination: EpisodeListView(show: show)) {
                            ShowRow(show: show)
                        }
                    }

                    // Load more trigger
                    if hasMorePages && searchText.isEmpty {
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
                                    Task { await loadShows(reset: false) }
                                }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search shows")
            }
        }
        .navigationTitle("Shows & Mixes")
        .task {
            if shows.isEmpty {
                await loadShows(reset: true)
            }
        }
    }

    private func loadShows(reset: Bool) async {
        if reset {
            isLoading = true
            currentPage = 1
            hasMorePages = true
        } else {
            guard !isLoadingMore, hasMorePages else { return }
            isLoadingMore = true
        }

        do {
            let fetched = try await AudioAddictAPI.shared.fetchShows(page: currentPage, perPage: perPage)
            await MainActor.run {
                if reset {
                    shows = fetched
                } else {
                    // Deduplicate by ID before appending
                    let existingIDs = Set(shows.map { $0.id })
                    shows.append(contentsOf: fetched.filter { !existingIDs.contains($0.id) })
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

// MARK: - Show Row

struct ShowRow: View {
    let show: Show

    var body: some View {
        HStack(spacing: 10) {
            // Artwork
            AsyncImage(url: show.cleanImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.mic")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(show.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                if let tagline = show.artistsTagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let count = show.ondemandEpisodeCount, count > 0 {
                    Text("\(count) episodes")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 2)
    }
}
