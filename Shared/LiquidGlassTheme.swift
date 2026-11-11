import SwiftUI
import UIKit

// MARK: - Semantic Light & Dark Adaptive Color Palette (Liquid Glass Design Language)
public enum GlassPalette {
    /// Primary background gradient top color (adapts automatically to Light & Dark themes)
    public static var canvasTop: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0)
                : UIColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 1.0)
        })
    }

    /// Primary background gradient bottom color
    public static var canvasBottom: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.11, blue: 0.20, alpha: 1.0)
                : UIColor(red: 0.88, green: 0.92, blue: 0.97, alpha: 1.0)
        })
    }

    /// Ambient gold orb glow
    public static var goldOrb: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.22)
                : UIColor(red: 0.96, green: 0.68, blue: 0.18, alpha: 0.18)
        })
    }

    /// Ambient cyan/teal orb glow
    public static var cyanOrb: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.72, blue: 0.83, alpha: 0.18)
                : UIColor(red: 0.08, green: 0.65, blue: 0.85, alpha: 0.14)
        })
    }

    /// Primary semantic text color
    public static var textPrimary: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.98, alpha: 1.0)
                : UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0)
        })
    }

    /// Secondary semantic text color
    public static var textSecondary: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.68, green: 0.74, blue: 0.84, alpha: 1.0)
                : UIColor(red: 0.35, green: 0.42, blue: 0.53, alpha: 1.0)
        })
    }

    /// Accent Gold for XAU/USD & primary highlights
    public static var accentGold: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.98, green: 0.75, blue: 0.18, alpha: 1.0)
                : UIColor(red: 0.78, green: 0.50, blue: 0.04, alpha: 1.0)
        })
    }

    /// Semantic Safe / Healthy Margin Green
    public static var safeEmerald: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 1.0)
                : UIColor(red: 0.05, green: 0.58, blue: 0.40, alpha: 1.0)
        })
    }

    /// Semantic Warning / Margin Call Amber
    public static var warningAmber: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.98, green: 0.68, blue: 0.20, alpha: 1.0)
                : UIColor(red: 0.85, green: 0.46, blue: 0.04, alpha: 1.0)
        })
    }

    /// Semantic Danger / Force Liquidation Coral Red
    public static var dangerCoral: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.97, green: 0.38, blue: 0.42, alpha: 1.0)
                : UIColor(red: 0.86, green: 0.15, blue: 0.22, alpha: 1.0)
        })
    }

    /// High-performance GPU-friendly card surface (translucent dark glass without expensive backdrop blur)
    public static var cardSurfaceFill: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 0.76)
                : UIColor(white: 1.0, alpha: 0.85)
        })
    }

    /// Translucent card surface tint
    public static var glassSurfaceTint: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.05)
                : UIColor(white: 1.0, alpha: 0.62)
        })
    }

    /// Specular rim border highlight (top-left)
    public static var specularHighlight: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.38)
                : UIColor(white: 1.0, alpha: 0.88)
        })
    }

    /// Specular rim border shadow (bottom-right)
    public static var specularLowlight: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.06)
                : UIColor(red: 0.55, green: 0.64, blue: 0.78, alpha: 0.28)
        })
    }
}

// MARK: - Ambient Liquid Glass Canvas Background (GPU Shader Acceleration, 0 Blur Passes)
public struct LiquidGlassBackground: View {
    public init() {}
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [GlassPalette.canvasTop, GlassPalette.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Hardware-accelerated radial fragment shaders (Zero Gaussian Blur passes, 120 FPS locked)
            RadialGradient(
                colors: [GlassPalette.goldOrb, Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 380
            )

            RadialGradient(
                colors: [GlassPalette.cyanOrb, Color.clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Reusable Liquid Glass Card Modifier (Zero-Backdrop GPU Fast-Path)
public struct LiquidGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    public var tintColor: Color?

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tintColor ?? GlassPalette.cardSurfaceFill)
                    .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                GlassPalette.specularHighlight,
                                GlassPalette.specularLowlight,
                                GlassPalette.specularHighlight.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.15
                    )
            )
    }
}

public extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 18,
        tint: Color? = nil
    ) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, padding: padding, tintColor: tint))
    }
}
