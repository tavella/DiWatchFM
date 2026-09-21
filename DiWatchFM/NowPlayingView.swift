import SwiftUI
import WatchKit
import AVFoundation

struct NowPlayingView: View {
    @Bindable var player = WatchAudioPlayer.shared
    private var favorites = FavoritesManager.shared
    
    private var isCurrentStationFavorited: Bool {
        guard let station = player.currentStation else { return false }
        return favorites.isFavorite(channelId: station.id)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            
            // Status Pill with Active Bitrate
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text(statusText)
                        .font(.system(size: 10, weight: .bold))
                    
                    Text("•")
                        .font(.system(size: 9, weight: .regular))
                        .opacity(0.6)
                    
                    Text(player.currentQuality.shortTitle)
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .cornerRadius(8)
            }
            
            if let errorMsg = player.lastErrorMessage {
                Text(errorMsg)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 6)
            }
            
            // Track Info
            VStack(spacing: 2) {
                MarqueeText(
                    text: player.trackTitle.isEmpty ? "Connecting..." : player.trackTitle,
                    font: .headline,
                    weight: .bold,
                    color: .primary
                )
                
                MarqueeText(
                    text: player.artistName.isEmpty ? "DI.FM" : player.artistName,
                    font: .subheadline,
                    weight: .regular,
                    color: .secondary
                )
                
                Text(player.currentEpisode?.show?.name ?? player.currentStation?.name ?? "Select a Station")
                    .font(.footnote)
                    .foregroundColor(.accentColor)
            }
            
            // Volume & Track Rating Row: [ 👎 Dislike ]  [ Volume Slider ]  [ 👍 Like ]
            HStack(spacing: 8) {
                // Thumbs Down (Dislike)
                Button(action: {
                    WKInterfaceDevice.current().play(.click)
                    player.toggleVoteDown()
                }) {
                    Image(systemName: player.currentTrackVote == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 34, height: 34)
                        .background(player.currentTrackVote == .down ? Color.red.opacity(0.3) : Color.gray.opacity(0.2))
                        .foregroundColor(player.currentTrackVote == .down ? .red : .secondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .disabled(player.currentTrackId == nil)
                
                // Native Hardware Volume Control (Crown-responsive, controls AirPods hardware volume directly)
                NativeVolumeView()
                    .frame(height: 34)
                
                // Thumbs Up (Like)
                Button(action: {
                    WKInterfaceDevice.current().play(.click)
                    player.toggleVoteUp()
                }) {
                    Image(systemName: player.currentTrackVote == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 34, height: 34)
                        .background(player.currentTrackVote == .up ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
                        .foregroundColor(player.currentTrackVote == .up ? .green : .secondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .disabled(player.currentTrackId == nil)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
            
            Spacer()
            
            // Balanced 3-Control Bar: [Favorite] [Play/Pause] [Next Channel]
            HStack(spacing: 24) {
                // Favorite Button (live stations only)
                Button(action: {
                    if let station = player.currentStation {
                        WKInterfaceDevice.current().play(.click)
                        favorites.toggleFavorite(channelId: station.id)
                    }
                }) {
                    Image(systemName: isCurrentStationFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isCurrentStationFavorited ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(player.currentStation == nil)
                
                // Play / Pause Button
                Button(action: {
                    WKInterfaceDevice.current().play(.click)
                    player.togglePlayPause()
                }) {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                // Skip Forward Button
                if player.currentEpisode == nil {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        player.skipForward()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal)
        .background {
            if let url = player.currentArtworkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 8)
                        .overlay(Color.black.opacity(0.3))
                        .scaleEffect(1.2)
                } placeholder: {
                    Color.black
                }
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        // Swipe left/right on screen to hop channels
        .gesture(
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    guard player.currentEpisode == nil else { return } // Disable swiping for episodes
                    if value.translation.width < -35 {
                        // Swiped Left -> Next Station
                        WKInterfaceDevice.current().play(.click)
                        player.skipForward()
                    } else if value.translation.width > 35 {
                        // Swiped Right -> Previous Station
                        WKInterfaceDevice.current().play(.click)
                        player.skipBackward()
                    }
                }
        )
    }
    
    private var statusText: String {
        switch player.state {
        case .playing: return player.currentEpisode != nil ? "ON DEMAND" : "LIVE STREAMING"
        case .buffering: return "BUFFERING"
        case .paused, .stopped: return player.lastErrorMessage != nil ? "ERROR" : "PAUSED"
        }
    }
    
    private var statusColor: Color {
        switch player.state {
        case .playing: return .green
        case .buffering: return .orange
        case .paused, .stopped: return player.lastErrorMessage != nil ? .red : .gray
        }
    }
    
    private var playPauseIcon: String {
        switch player.state {
        case .playing, .buffering: return "pause.circle.fill"
        default: return "play.circle.fill"
        }
    }
}

struct NativeVolumeView: WKInterfaceObjectRepresentable {
    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        let control = WKInterfaceVolumeControl(origin: .local)
        DispatchQueue.main.async {
            control.focus()
        }
        return control
    }
    
    func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceVolumeControl, context: Context) {
    }
}

struct MarqueeText: View {
    let text: String
    let font: Font
    let weight: Font.Weight
    let color: Color
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(weight)
            .lineLimit(1)
            .hidden() // Hidden base for intrinsic height
            .overlay(
                GeometryReader { geo in
                    Text(text)
                        .font(font)
                        .fontWeight(weight)
                        .foregroundColor(color)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(GeometryReader { tGeo -> Color in
                            DispatchQueue.main.async {
                                self.textWidth = tGeo.size.width
                                self.containerWidth = geo.size.width
                            }
                            return Color.clear
                        })
                        .offset(x: offset)
                        .onAppear { startAnimation() }
                        .onChange(of: text) {
                            offset = 0
                            startAnimation()
                        }
                        .onChange(of: textWidth) { startAnimation() }
                        .onChange(of: containerWidth) { startAnimation() }
                }
                .clipped()
            )
    }
    
    private func startAnimation() {
        let diff = textWidth - containerWidth
        if diff > 0 {
            withAnimation(Animation.linear(duration: Double(diff) / 25.0).delay(2.0).repeatForever(autoreverses: true)) {
                offset = -diff
            }
        } else {
            withAnimation { offset = 0 }
        }
    }
}
