import SwiftUI

// MARK: - Liquid Glass Theme for DiPhoneFM

struct LiquidGlassBackground: View {
    @State private var animateGlow: Bool = false
    
    var body: some View {
        ZStack {
            // Deep obsidian base
            Color(red: 0.04, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            // Ambient blooming liquid gradient orbs
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.28),
                                    Color.blue.opacity(0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 180
                            )
                        )
                        .frame(width: 320, height: 320)
                        .offset(x: animateGlow ? -40 : 40, y: animateGlow ? -60 : 20)
                        .blur(radius: 50)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.15, blue: 0.9).opacity(0.25),
                                    Color.purple.opacity(0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 200
                            )
                        )
                        .frame(width: 340, height: 340)
                        .offset(x: animateGlow ? geo.size.width * 0.4 : geo.size.width * 0.1,
                                y: animateGlow ? geo.size.height * 0.35 : geo.size.height * 0.5)
                        .blur(radius: 60)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.85, blue: 0.75).opacity(0.18),
                                    Color.teal.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 160
                            )
                        )
                        .frame(width: 260, height: 260)
                        .offset(x: animateGlow ? 20 : geo.size.width * 0.3,
                                y: animateGlow ? geo.size.height * 0.75 : geo.size.height * 0.65)
                        .blur(radius: 45)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGlow.toggle()
            }
        }
    }
}

// MARK: - Liquid Glass Card Modifier

struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 22
    var strokeOpacity: Double = 0.35
    
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
                                        Color.white.opacity(0.12),
                                        Color.cyan.opacity(0.15),
                                        Color.clear,
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
            }
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 22, strokeOpacity: Double = 0.35) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    var isProminent: Bool = true
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background {
                if isDestructive {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.red.opacity(configuration.isPressed ? 0.35 : 0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                } else if isProminent {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 0.75, blue: 0.95),
                                        Color(red: 0.45, green: 0.2, blue: 0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(configuration.isPressed ? 0.8 : 1.0)
                        
                        // Specular glass shine
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.clear,
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
                    .shadow(color: Color.cyan.opacity(0.4), radius: configuration.isPressed ? 6 : 14, x: 0, y: configuration.isPressed ? 2 : 6)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .foregroundColor(isDestructive ? .red : .white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
