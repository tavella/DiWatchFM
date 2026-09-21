import SwiftUI
import WatchKit

// MARK: - WatchOS Liquid Glass Design System

struct WatchLiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var strokeOpacity: Double = 0.28
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(strokeOpacity),
                                        Color.cyan.opacity(0.12),
                                        Color.clear,
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )
            }
    }
}

extension View {
    func watchLiquidGlass(cornerRadius: CGFloat = 16, strokeOpacity: Double = 0.28) -> some View {
        modifier(WatchLiquidGlassCard(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}

// MARK: - Circular Liquid Glass Control Button

struct CircularLiquidGlassButton: View {
    let icon: String
    let size: CGFloat
    var iconSize: CGFloat = 18
    var accentColor: Color = .white
    var isSelected: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            action()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: isSelected ?
                                        [accentColor.opacity(0.8), accentColor.opacity(0.2)] :
                                        [Color.white.opacity(0.35), Color.clear, Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 1.5 : 1.0
                            )
                    )
                    .shadow(color: isSelected ? accentColor.opacity(0.4) : Color.black.opacity(0.3), radius: isSelected ? 8 : 4)
                
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(isSelected ? accentColor : .white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

// MARK: - Prominent Liquid Glass Play/Pause Button

struct ProminentLiquidGlassPlayButton: View {
    var isPlaying: Bool
    var size: CGFloat = 52
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            action()
        }) {
            ZStack {
                // True circular glass material - no rectangular background box
                Circle()
                    .fill(.ultraThinMaterial)
                
                // Vibrant liquid accent gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(isPlaying ? 0.38 : 0.20),
                                Color(red: 0.35, green: 0.15, blue: 0.85).opacity(isPlaying ? 0.28 : 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Specular glass highlight ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.65),
                                Color.cyan.opacity(0.40),
                                Color.clear,
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                
                // Play / Pause Icon
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: isPlaying ? 0 : 1.5) // Optical centering for play triangle
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: Color.cyan.opacity(isPlaying ? 0.45 : 0.18), radius: isPlaying ? 9 : 4)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

// MARK: - Ambient Liquid Background for Watch

struct WatchAmbientLiquidBackground: View {
    var artworkURL: URL?
    var isPlaying: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let url = artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 28)
                            .scaleEffect(1.3)
                            .overlay(
                                // Radial vignette ensuring deep OLED black edges
                                RadialGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.40),
                                        Color.black.opacity(0.85),
                                        Color.black
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 130
                                )
                            )
                            .overlay(
                                // Bottom fade so bottom controls rest on dark backdrop
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.4),
                                        Color.black.opacity(0.85)
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                    case .failure, .empty:
                        ambientOrbs
                    @unknown default:
                        ambientOrbs
                    }
                }
                .ignoresSafeArea()
            } else {
                ambientOrbs
                    .ignoresSafeArea()
            }
            
            // Subtle specular ambient sheen at the top
            LinearGradient(
                colors: [
                    Color.cyan.opacity(isPlaying ? 0.10 : 0.04),
                    Color.clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    private var ambientOrbs: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(isPlaying ? 0.25 : 0.10), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 90
                    )
                )
                .frame(width: 140, height: 140)
                .offset(x: -30, y: -40)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(isPlaying ? 0.20 : 0.08), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 100
                    )
                )
                .frame(width: 150, height: 150)
                .offset(x: 40, y: 50)
        }
    }
}

