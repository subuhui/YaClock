import SwiftUI

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Liquid Glass Background
struct AmbientLiquidBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Deep futuristic dark base
            LinearGradient(
                colors: [Color(hex: "08090C"), Color(hex: "101116")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Glowing liquid blobs that drift organically
            GeometryReader { geo in
                ZStack {
                    // Blob 1: Aurora Cyan
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "00F2FE"), Color(hex: "4FACFE")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                        .blur(radius: 80)
                        .opacity(0.35)
                        .offset(
                            x: animate ? geo.size.width * 0.3 : -geo.size.width * 0.2,
                            y: animate ? -geo.size.height * 0.1 : geo.size.height * 0.15
                        )

                    // Blob 2: Electric Magenta
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "FF0844"), Color(hex: "FFB199")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: geo.size.width * 0.95, height: geo.size.width * 0.95)
                        .blur(radius: 90)
                        .opacity(0.25)
                        .offset(
                            x: animate ? -geo.size.width * 0.3 : geo.size.width * 0.25,
                            y: animate ? geo.size.height * 0.35 : -geo.size.height * 0.05
                        )

                    // Blob 3: Neon Purple
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "B883FF"), Color(hex: "8A2387")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                        .blur(radius: 75)
                        .opacity(0.3)
                        .offset(
                            x: animate ? geo.size.width * 0.05 : -geo.size.width * 0.35,
                            y: animate ? geo.size.height * 0.25 : geo.size.height * 0.05
                        )
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - Liquid Glass Card Modifier
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var shadowColor: Color
    var strokeColors: [Color]
    
    init(
        cornerRadius: CGFloat = 24,
        shadowColor: Color = Color.black.opacity(0.25),
        strokeColors: [Color] = [.white.opacity(0.3), .white.opacity(0.05), .black.opacity(0.15), .white.opacity(0.15)]
    ) {
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.strokeColors = strokeColors
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: strokeColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
    }
}

extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = 24,
        shadowColor: Color = Color.black.opacity(0.25),
        strokeColors: [Color] = [.white.opacity(0.3), .white.opacity(0.05), .black.opacity(0.15), .white.opacity(0.15)]
    ) -> some View {
        self.modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            shadowColor: shadowColor,
            strokeColors: strokeColors
        ))
    }
}
