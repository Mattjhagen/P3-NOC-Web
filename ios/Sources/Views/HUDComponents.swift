import SwiftUI
import UIKit

// MARK: - Metro Style Colors
extension Color {
    static let cyberGreen = Color(red: 0.0, green: 0.9, blue: 0.45) // Flat Metro Green
    static let cyberBlue = Color(red: 0.0, green: 0.7, blue: 0.85)  // Flat Metro Accent Blue
    static let cyberRed = Color(red: 0.94, green: 0.14, blue: 0.24)  // Flat Metro Red
    static let cyberYellow = Color(red: 1.0, green: 0.82, blue: 0.4) // Flat Metro Yellow
    static let cyberTerminalBg = Color(red: 0.06, green: 0.06, blue: 0.06) // Flat #0f0f0f
    static let cyberGlassBg = Color(red: 0.1, green: 0.1, blue: 0.1) // Flat #1a1a1a
    
    // Additional explicit Metro tokens
    static let metroAccent = Color(red: 0.0, green: 0.7, blue: 0.85)
    static let metroBg = Color(red: 0.06, green: 0.06, blue: 0.06)
    static let metroSurface = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let metroBorder = Color(white: 1.0, opacity: 0.06)
    static let metroMuted = Color(white: 1.0, opacity: 0.35)
}

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }
    
    func selection() {
        DispatchQueue.main.async {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }
}

// MARK: - Metro Clean Overlay (Removes scanlines/raster grids)
struct CRTScanlineOverlay: View {
    var body: some View {
        EmptyView() // Metro is pure flat, digital typography
    }
}

// MARK: - Flat Metro Borders & Panels (No Rounded Corners, No Shadows)
struct NeonBorder: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat
    let isPulsing: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle() // Strict flat corners
                    .stroke(color, lineWidth: 1.5)
            )
    }
}

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content // Strip all neon glow filters for authentic Windows Phone design
    }
}

struct GlassPanel: ViewModifier {
    let cornerRadius: CGFloat
    let borderColor: Color
    
    func body(content: Content) -> some View {
        content
            .background(Color.cyberGlassBg)
            .overlay(
                Rectangle() // Sharp edges
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    func hudNeonBorder(color: Color, cornerRadius: CGFloat = 0, isPulsing: Bool = false) -> some View {
        self.modifier(NeonBorder(color: color, cornerRadius: 0, isPulsing: isPulsing))
    }
    
    func hudNeonGlow(color: Color, radius: CGFloat = 0) -> some View {
        self.modifier(NeonGlow(color: color, radius: radius))
    }
    
    func hudGlassPanel(cornerRadius: CGFloat = 0, borderColor: Color = Color.white.opacity(0.06)) -> some View {
        self.modifier(GlassPanel(cornerRadius: 0, borderColor: borderColor))
    }
}

// MARK: - Metro Typography View Extensions
struct MetroTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 48, weight: .light, design: .default))
            .tracking(-1)
            .foregroundColor(.white)
    }
}

struct MetroSubtitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 24, weight: .light, design: .default))
            .tracking(-0.5)
            .foregroundColor(.white)
    }
}

struct MetroLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .semibold, design: .default))
            .tracking(1.5)
            .foregroundColor(Color.white.opacity(0.35))
            .textCase(.uppercase)
    }
}

struct MetroValue: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 32, weight: .bold, design: .default))
            .tracking(-1.5)
    }
}

extension View {
    func metroTitleStyle() -> some View {
        self.modifier(MetroTitle())
    }
    
    func metroSubtitleStyle() -> some View {
        self.modifier(MetroSubtitle())
    }
    
    func metroLabelStyle() -> some View {
        self.modifier(MetroLabel())
    }
    
    func metroValueStyle() -> some View {
        self.modifier(MetroValue())
    }
}
