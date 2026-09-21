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
        ZStack {
            // Ambient Liquid Glass Background across entire watch display
            WatchAmbientLiquidBackground(
                artworkURL: player.currentArtworkURL,
                isPlaying: player.state == .playing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 5) {
                Spacer()
                
                // Status Pill with Active Bitrate in Frosted Glass Capsule
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 5, height: 5)
                            .shadow(color: statusColor.opacity(0.8), radius: 3)
                        
                        Text(statusText)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                        
                        Text("•")
                            .font(.system(size: 8))
                            .opacity(0.4)
                        
                        Text(player.currentQuality.shortTitle)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        statusColor.opacity(0.5),
                                        Color.white.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .foregroundColor(statusColor)
                }
                
                if let errorMsg = player.lastErrorMessage {
                    Text(errorMsg)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 6)
                }
                
                // Track Info Card in Liquid Glass Plate
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
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.cyan)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                
                // Volume & Track Rating Row with Glass Controls
                HStack(spacing: 8) {
                    // Thumbs Down (Dislike)
                    CircularLiquidGlassButton(
                        icon: player.currentTrackVote == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                        size: 34,
                        iconSize: 13,
                        accentColor: .red,
                        isSelected: player.currentTrackVote == .down
                    ) {
                        player.toggleVoteDown()
                    }
                    .disabled(player.currentTrackId == nil)
                    
                    // Native Hardware Volume Control (Crown-responsive, system styled)
                    NativeVolumeView()
                        .frame(height: 34)
                    
                    // Thumbs Up (Like)
                    CircularLiquidGlassButton(
                        icon: player.currentTrackVote == .up ? "hand.thumbsup.fill" : "hand.thumbsup",
                        size: 34,
                        iconSize: 13,
                        accentColor: .green,
                        isSelected: player.currentTrackVote == .up
                    ) {
                        player.toggleVoteUp()
                    }
                    .disabled(player.currentTrackId == nil)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                
                Spacer()
                
                // Balanced 3-Control Bar: [Favorite] [Play/Pause Glass Button] [Next Channel]
                HStack(spacing: 20) {
                    // Favorite Button
                    CircularLiquidGlassButton(
                        icon: isCurrentStationFavorited ? "heart.fill" : "heart",
                        size: 38,
                        iconSize: 18,
                        accentColor: .red,
                        isSelected: isCurrentStationFavorited
                    ) {
                        if let station = player.currentStation {
                            favorites.toggleFavorite(channelId: station.id)
                        }
                    }
                    .disabled(player.currentStation == nil)
                    
                    // Prominent Play / Pause Glass Button
                    ProminentLiquidGlassPlayButton(
                        isPlaying: player.state == .playing || player.state == .buffering,
                        size: 52
                    ) {
                        player.togglePlayPause()
                    }
                    
                    // Skip Forward Button
                    if player.currentEpisode == nil {
                        CircularLiquidGlassButton(
                            icon: "forward.fill",
                            size: 38,
                            iconSize: 17,
                            accentColor: .cyan,
                            isSelected: false
                        ) {
                            player.skipForward()
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal)
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
